###############################################################################
# TERRAFORM CONFIGURATION
###############################################################################
terraform {
  # Enforces a minimum Terraform version to ensure compatibility
  required_version = ">= 1.0.0"

  # ----------------------------------------------------------------------------
  # Required Providers - including the HashiCorp AWS provider v ~>5.0 and Random
  # provider v ~>3.5 as detailed in the JSON specification.
  # ----------------------------------------------------------------------------
  required_providers {
    # hashicorp/aws version ~> 5.0
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # hashicorp/random version ~> 3.5
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

###############################################################################
# DATA RESOURCE: AWS Secrets Manager Secret for JWT_SECRET
# -----------------------------------------------------------------------------
# This data block references an existing secret in AWS Secrets Manager that
# stores the JWT signing secret for the authentication service. It is used
# inside the container_definition block as "valueFrom" to securely inject
# secrets at runtime.
###############################################################################
data "aws_secretsmanager_secret" "jwt_secret" {
  name = "jwt_secret-${var.environment}"
}

###############################################################################
# RESOURCE: AWS SECURITY GROUP FOR AUTH SERVICE
# -----------------------------------------------------------------------------
# Implements secure network configuration for the Authentication service
# (see 2.4.2 Security Architecture) and references var.security_config for
# inbound rules. This ensures we have an isolated environment for the ECS tasks.
###############################################################################
resource "aws_security_group" "auth" {
  name        = "${var.service_name}-${var.environment}-sg"
  description = "Security group for the ${var.service_name} in environment ${var.environment}"
  vpc_id      = var.vpc_id

  # Dynamically create ingress rules from security_config.security_group_rules
  dynamic "ingress" {
    for_each = var.security_config.security_group_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.type
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  # Example egress rule allowing all outbound connectivity
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Assign tags for resource association and identification
  tags = merge(
    var.tags,
    {
      Name  = "${var.service_name}-${var.environment}-sg"
      Scope = "Authentication-SecurityGroup"
    }
  )
}

###############################################################################
# RESOURCE: AWS CLOUDWATCH LOG GROUP FOR AUTH SERVICE
# -----------------------------------------------------------------------------
# Centralized log group to store container logs for the authentication service.
# This is part of the monitoring_config to meet auditing and compliance (7.3.5).
###############################################################################
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/ecs/${var.service_name}-${var.environment}"
  retention_in_days = var.monitoring_config.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "cw-logs-${var.service_name}-${var.environment}"
    }
  )
}

###############################################################################
# RESOURCE: AWS ECS CLUSTER (AUTH)
# -----------------------------------------------------------------------------
# Core ECS cluster for running the Auth Service Fargate tasks. Container
# Insights is enabled for metrics, and execute command configuration is
# set to allow secure interactive shell access. Fulfills part of the
# High Availability requirement (2.5.1) and references system architecture
# guidelines (2.2.1).
###############################################################################
resource "aws_ecs_cluster" "auth" {
  name = "${var.service_name}-${var.environment}"

  # Enable Container Insights for deeper monitoring
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  # Configure ECS Exec for secure shell access and encrypted logging
  execute_command_configuration {
    logging = "OVERRIDE"
    log_configuration {
      cloud_watch_encryption_enabled = true
      # Optionally attach a log group name here if desired for ECS Exec audits
    }
  }

  # Apply relevant tagging structure
  tags = merge(
    var.tags,
    {
      Service = "Authentication"  # As specified in the JSON for ECS cluster
    }
  )
}

###############################################################################
# LOCAL BLOCKS FOR CONTAINER DEFINITION CONSTRUCTION
# -----------------------------------------------------------------------------
# Combining environment variables from container_config with essential
# Auth settings (e.g., JWT expiration, environment).
###############################################################################
locals {
  # Merges base environment variables required for the auth service with any
  # user-provided environment_variables from var.container_config.
  base_env_vars = [
    {
      name  = "NODE_ENV"
      value = var.environment
    },
    {
      name  = "JWT_EXPIRY"
      value = var.auth_config.jwt_config.expiry
    },
    {
      name  = "AWS_XRAY_DAEMON_ADDRESS"
      value = "localhost:2000"
    }
  ]

  merged_environment = concat(
    local.base_env_vars,
    [
      for k, v in var.container_config.environment_variables : {
        name  = k
        value = v
      }
    ]
  )

  # Construct the container definitions in JSON format for the ECS task.
  # This includes the health check, logging configuration, environment,
  # secrets references, etc. The specification explicitly shows a single
  # container scenario with a port mapping.
  container_definitions = jsonencode([
    {
      name       = var.service_name
      image      = var.container_config.image
      cpu        = var.container_config.cpu
      memory     = var.container_config.memory
      essential  = true
      portMappings = [
        {
          containerPort = var.container_config.port
          protocol      = "tcp"
        }
      ]
      environment = local.merged_environment
      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = data.aws_secretsmanager_secret.jwt_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-region        = var.aws_region
          awslogs-group         = aws_cloudwatch_log_group.auth.name
          awslogs-stream-prefix = "ecs"
          # "awslogs-encrypt" isn't an official parameter, but included
          # here per given JSON specification illustration.
          awslogs-encrypt = "true"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_config.port}${var.container_config.health_check_path} || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

###############################################################################
# RESOURCE: AWS ECS TASK DEFINITION (AUTH)
# -----------------------------------------------------------------------------
# Defines the container for the auth service using Fargate, incorporating
# CPU/memory from container_config, environment variables, secrets, and
# log configuration from monitoring_config. Aligns with enterprise design
# (2.2.1) and security guidelines (2.4.2).
###############################################################################
resource "aws_ecs_task_definition" "auth" {
  family                   = var.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  # Container sizing from container_config
  cpu    = var.container_config.cpu
  memory = var.container_config.memory

  # IAM roles for execution and task. These roles must be defined externally
  # or in a higher-level configuration.
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  # Rendered container definitions from local.container_definitions JSON
  container_definitions = local.container_definitions

  # Ensure the latest platform for Fargate
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # Tag resources for centralized identification
  tags = merge(
    var.tags,
    {
      Service = "AuthTaskDefinition"
    }
  )
}

###############################################################################
# RESOURCE: AWS ECS SERVICE (AUTH)
# -----------------------------------------------------------------------------
# Deploys the Auth Service tasks onto Fargate with a load balancer, references
# the cluster, and sets up the target group and service discovery. High
# Availability is addressed through multi-AZ subnets and a desired count that
# can scale according to scaling_config (2.5.1).
###############################################################################
resource "aws_ecs_service" "auth" {
  name            = "${var.service_name}-${var.environment}"
  cluster         = aws_ecs_cluster.auth.id
  task_definition = aws_ecs_task_definition.auth.arn

  # The initial desired_count is set to the minimum capacity from scaling_config
  desired_count = var.scaling_config.min_capacity

  # Using FARGATE launch type in a private subnet for improved security posture
  launch_type        = "FARGATE"
  platform_version   = "LATEST"
  propagate_tags     = "SERVICE"

  deployment_controller {
    type = "ECS"
  }

  # Let tasks warm up before health checks
  health_check_grace_period_seconds = 60
  enable_execute_command            = true

  # VPC network configuration referencing the newly created auth SG
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.auth.id]
    assign_public_ip = false
  }

  # Attach to an external target group (ALB or NLB) for load balancing
  load_balancer {
    target_group_arn = aws_lb_target_group.auth.arn
    container_name   = var.service_name
    container_port   = var.container_config.port
  }

  # Optionally integrates with AWS Cloud Map (Service Discovery)
  service_registries {
    registry_arn = aws_service_discovery_service.auth.arn
  }

  # Tagging for identification
  tags = var.tags
}

###############################################################################
# RESOURCE: APPLICATION AUTO SCALING TARGET (AUTH)
# -----------------------------------------------------------------------------
# This configures horizontal scaling of the desired_count for the ECS service
# based on min/max capacity from var.scaling_config. This addresses the
# requirement for advanced auto-scaling from the project specification.
###############################################################################
resource "aws_appautoscaling_target" "auth_desired_count" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.auth.name}/${aws_ecs_service.auth.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.scaling_config.min_capacity
  max_capacity       = var.scaling_config.max_capacity
}

###############################################################################
# RESOURCE: APPLICATION AUTO SCALING POLICY (AUTH) - CPU TARGET TRACKING
# -----------------------------------------------------------------------------
# Automatically scale the ECS service based on CPU usage. The target CPU
# utilization is read from var.scaling_config.
###############################################################################
resource "aws_appautoscaling_policy" "auth_cpu_policy" {
  name               = "${var.service_name}-cpu-policy-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auth_desired_count.resource_id
  scalable_dimension = aws_appautoscaling_target.auth_desired_count.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auth_desired_count.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_config.target_cpu_utilization
    scale_in_cooldown  = var.scaling_config.scale_in_cooldown
    scale_out_cooldown = var.scaling_config.scale_out_cooldown
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

###############################################################################
# RESOURCE: APPLICATION AUTO SCALING POLICY (AUTH) - MEMORY TARGET TRACKING
# -----------------------------------------------------------------------------
# Automatically scale the ECS service based on Memory usage. The target memory
# utilization is from var.scaling_config.
###############################################################################
resource "aws_appautoscaling_policy" "auth_memory_policy" {
  name               = "${var.service_name}-memory-policy-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.auth_desired_count.resource_id
  scalable_dimension = aws_appautoscaling_target.auth_desired_count.scalable_dimension
  service_namespace  = aws_appautoscaling_target.auth_desired_count.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.scaling_config.target_memory_utilization
    scale_in_cooldown  = var.scaling_config.scale_in_cooldown
    scale_out_cooldown = var.scaling_config.scale_out_cooldown
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

###############################################################################
# OPTIONAL: APPLICATION AUTO SCALING POLICY (AUTH) - CUSTOM METRICS
# -----------------------------------------------------------------------------
# For advanced use cases, var.scaling_config.custom_metrics can be processed
# here to create additional scaling policies. Each item in the custom_metrics
# array can define a unique metric_name and target_value. Uncomment or tailor
# as needed:
###############################################################################
# resource "aws_appautoscaling_policy" "auth_custom_metric_policy" {
#   count              = length(var.scaling_config.custom_metrics)
#   name               = "${var.service_name}-custom-\${element(var.scaling_config.custom_metrics.*, count.index).metric_name}-${var.environment}"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.auth_desired_count.resource_id
#   scalable_dimension = aws_appautoscaling_target.auth_desired_count.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.auth_desired_count.service_namespace
#
#   target_tracking_scaling_policy_configuration {
#     target_value       = element(var.scaling_config.custom_metrics.*, count.index).target_value
#     scale_in_cooldown  = var.scaling_config.scale_in_cooldown
#     scale_out_cooldown = var.scaling_config.scale_out_cooldown
#     customized_metric_specification {
#       metric_name = element(var.scaling_config.custom_metrics.*, count.index).metric_name
#       namespace   = "Custom/ECS/AuthService"
#       statistic   = "Average"
#     }
#   }
# }

###############################################################################
# OUTPUTS
###############################################################################

###############################################################################
# OUTPUT: cluster_id
# -----------------------------------------------------------------------------
# Exports the ID of the created ECS cluster for referencing in other modules
# or higher-level configurations.
###############################################################################
output "cluster_id" {
  description = "ECS cluster identifier for the Auth Service"
  value       = aws_ecs_cluster.auth.id
}

###############################################################################
# OUTPUT: service_name
# -----------------------------------------------------------------------------
# Exports the name of the ECS service for cross-module references, monitoring,
# or service discovery usage.
###############################################################################
output "service_name" {
  description = "ECS Service logical name for the Auth Service"
  value       = aws_ecs_service.auth.name
}

###############################################################################
# OUTPUT: security_group_id
# -----------------------------------------------------------------------------
# Exports the security group ID that has been created for the auth service,
# enabling cross-reference in other modules (e.g., ALB rules, WAF, or other
# microservices).
###############################################################################
output "security_group_id" {
  description = "Security Group ID for the Auth Service"
  value       = aws_security_group.auth.id
}