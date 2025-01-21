###############################################################################
# TERRAFORM CONFIGURATION FOR THE BOOKING SERVICE MODULE
# -----------------------------------------------------------------------------
# This file provisions and manages the Java/Spring-based booking service
# infrastructure on AWS ECS Fargate. It:
#   1) Creates or references an ECS Cluster with capacity providers (FARGATE,
#      FARGATE_SPOT) and container insights for enhanced monitoring.
#   2) Defines a CloudWatch log group with a configurable retention period
#      for centralized logging.
#   3) Manages IAM roles for ECS task execution, including permissions for
#      reading secret values from AWS Secrets Manager if needed.
#   4) Creates an ECS Task Definition with advanced container settings:
#      - Environment variables referencing the imported MongoDB connection.
#      - Secure secrets injection referencing the MongoDB secret ARN.
#      - Optional AWS App Mesh sidecar proxy configuration for service mesh
#        integration.
#   5) Stands up an ECS Service with:
#      - Load Balancer integration (ALB) for HTTP traffic.
#      - Deployment circuit breaker for automated rollback of unhealthy
#        deployments.
#      - Service discovery (Cloud Map) for DNS-based discovery across the
#        microservices environment.
#      - Auto-scaling rules (target tracking for CPU/Memory) scaling tasks
#        between min_capacity and max_capacity.
#      - Optional bridging to an existing AWS App Mesh, referencing the
#        passed-in mesh ID for advanced routing and observability.
#
# References / Requirements:
#   - Booking Service Architecture and Infrastructure Requirements (Technical
#     Specs sections 2.1, 2.5.1).
#   - Service Integration with MongoDB and advanced service mesh (Technical
#     Specs sections 3.3.4).
#   - Enhanced security and monitoring, including log retention (Technical
#     Specs sections 2.4, 7.2).
###############################################################################

###############################################################################
# REQUIRED PROVIDERS
# We specify the AWS provider (version ~> 5.0) per the JSON specification's
# external import requirement. This enables the creation and management of
# ECS, ALB, IAM, and related AWS resources.
###############################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS provider ~> 5.0
    }
  }
}

###############################################################################
# LOCALS
# These local values come from the JSON specification ("globals") and define
# key configuration defaults for the booking service. They include container
# size, health check endpoints, scaling limits, and log retention parameters.
###############################################################################
locals {
  service_name               = "booking-service"
  container_port            = 8080
  desired_count             = 2
  max_capacity              = 10
  min_capacity              = 2
  health_check_path         = "/actuator/health"
  health_check_grace_period = 60
  container_memory          = 2048
  container_cpu             = 1024
  log_retention_days        = 30
}

###############################################################################
# IMPORTS FROM OTHER MODULES / FILES
# 1) Variables & configuration for environment, VPC, subnets, and service mesh:
#    - var.environment
#    - var.vpc_id
#    - var.subnet_ids
#    - var.service_mesh_id
#
# 2) Database module outputs for MongoDB connection:
#    - mongodb_connection_string
#    - mongodb_secret_arn
#
# In a real-world setup, these might come from a root module that declares all
# inputs and calls this "booking-service" module. Below is an example snippet
# if referencing the database module:
#
# module "database" {
#   source      = "../database"
#   environment = var.environment
#   # ... additional variables for region, subnets, etc.
# }
#
# For the purpose of this code, we assume var.mongodb_connection_string and
# var.mongodb_secret_arn are passed in or retrieved via remote state:
#
# data "terraform_remote_state" "database" {
#   backend = "s3" # or any other backend
#   config = {
#     bucket = "example-remote-state-bucket"
#     key    = "database/terraform.tfstate"
#     region = "us-east-1"
#   }
# }
#
# Then you might reference:
#   local.mongodb_connection = data.terraform_remote_state.database.outputs.mongodb_connection_string
#   local.mongodb_secret_arn = data.terraform_remote_state.database.outputs.mongodb_secret_arn
#
# For now, we simply assume the following variables are set:
#   var.mongodb_connection_string
#   var.mongodb_secret_arn
###############################################################################

###############################################################################
# PROVIDER CONFIGURATION
# Typically configured at a higher-level (root) module. Shown here for clarity.
###############################################################################
provider "aws" {
  # If needed, region or other settings can be specified or inherited.
  # e.g.: region = "us-east-1"
}

###############################################################################
# DATA REFERENCE FOR AWS APP MESH (OPTIONAL)
# If the booking service must integrate with an existing AWS App Mesh, we
# reference the mesh by name (var.service_mesh_id). This allows us to attach
# the ECS tasks to that mesh for advanced routing and observability. If your
# mesh is identified by ARN, adjust accordingly.
###############################################################################
data "aws_appmesh_mesh" "this" {
  name = var.service_mesh_id
  # If var.service_mesh_id is an ARN, use 'mesh_name = ...' form or
  # adapt as needed. This is a demonstration of referencing the mesh.
}

###############################################################################
# CREATE A CLOUDWATCH LOG GROUP
# This log group captures container logs for the booking service. We retain
# logs for a configurable period (locals.log_retention_days).
###############################################################################
resource "aws_cloudwatch_log_group" "booking_service_logs" {
  name              = "/ecs/${local.service_name}"
  retention_in_days = local.log_retention_days

  tags = {
    Application = local.service_name
    Environment = var.environment
    Module      = "booking-service"
  }
}

###############################################################################
# CREATE THE ECS CLUSTER
# This block implements a portion of the "create_ecs_cluster" function
# (per the JSON specification) by defining an ECS Cluster with container
# insights enabled, capacity providers, and relevant tags.
###############################################################################
resource "aws_ecs_cluster" "booking_service_cluster" {
  name               = "${var.environment}-${local.service_name}-cluster"
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]  # Example usage
  settings {
    name  = "containerInsights"
    value = "enabled"
  }

  # Example usage of default capacity provider strategy (optional).
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight           = 1
    base             = 1
  }

  tags = {
    Name        = "${var.environment}-${local.service_name}-cluster"
    Environment = var.environment
    Module      = "booking-service"
  }
}

###############################################################################
# IAM ROLE FOR ECS TASK EXECUTION
# Grants the ECS agent permissions to pull container images from ECR (if used)
# and write container logs to CloudWatch. Additionally, if we must read secrets
# from AWS Secrets Manager, we can attach a policy for that.
###############################################################################
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.environment}-${local.service_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name        = "${var.environment}-${local.service_name}-exec-role"
    Environment = var.environment
    Module      = "booking-service"
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Attach AmazonECSTaskExecutionRolePolicy for basic ECS tasks usage
resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# Optional policy for reading secret from AWS Secrets Manager
data "aws_iam_policy_document" "secret_read_doc" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      var.mongodb_secret_arn
    ]
  }
}

resource "aws_iam_policy" "secret_read" {
  name   = "${var.environment}-${local.service_name}-secret-read"
  policy = data.aws_iam_policy_document.secret_read_doc.json
}

resource "aws_iam_role_policy_attachment" "secret_read_attach" {
  policy_arn = aws_iam_policy.secret_read.arn
  role       = aws_iam_role.ecs_task_execution_role.name
}

###############################################################################
# CREATE THE ECS TASK DEFINITION
# This implements "create_task_definition" from the JSON specification with
# advanced container configurations, environment variables for the MongoDB
# connection, and optional App Mesh sidecar proxy container.
###############################################################################
resource "aws_ecs_task_definition" "booking_service_task" {
  family                   = local.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.container_cpu
  memory                   = local.container_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn  # Or a separate role if needed
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  # We define two containers: the main booking container and an Envoy sidecar
  # for AWS App Mesh integration, referencing data.aws_appmesh_mesh.this.
  container_definitions = jsonencode(
    [
      {
        "name"        : local.service_name,
        "image"       : var.booking_container_image, # Provided externally
        "cpu"         : 0,
        "memory"      : 0,
        "essential"   : true,
        "portMappings": [
          {
            "containerPort": local.container_port,
            "hostPort"     : local.container_port,
            "protocol"     : "tcp"
          }
        ],
        "environment": [
          {
            "name" : "ENVIRONMENT",
            "value": var.environment
          },
          {
            "name" : "MONGODB_CONNECTION_STRING",
            "value": var.mongodb_connection_string
          }
        ],
        "secrets": [
          {
            "name"      : "MONGODB_SECRET",
            "valueFrom" : var.mongodb_secret_arn
          }
        ],
        "logConfiguration": {
          "logDriver" : "awslogs",
          "options"   : {
            "awslogs-group"         : aws_cloudwatch_log_group.booking_service_logs.name,
            "awslogs-region"        : "us-east-1",
            "awslogs-stream-prefix" : "${local.service_name}"
          }
        }
      },
      # Optional Envoy container if service mesh integration is required.
      # This references the existing mesh name from data.aws_appmesh_mesh.this.
      {
        "name"            : "envoy",
        "image"           : "public.ecr.aws/appmesh/aws-appmesh-envoy:v1.21.1.0-prod",
        "essential"       : true,
        "environment"     : [
          {
            "name" : "APPMESH_VIRTUAL_NODE_NAME",
            "value": "mesh/${data.aws_appmesh_mesh.this.name}/virtualNode/${local.service_name}-vn"
          }
        ],
        "logConfiguration": {
          "logDriver": "awslogs",
          "options"  : {
            "awslogs-group"         : aws_cloudwatch_log_group.booking_service_logs.name,
            "awslogs-region"        : "us-east-1",
            "awslogs-stream-prefix" : "envoy"
          }
        }
      }
    ]
  )

  # Proxy configuration is defined to enable AWS App Mesh sidecar injection.
  # The containerName must match the Envoy container name above.
  proxy_configuration {
    type           = "APPMESH"
    container_name = "envoy"
    properties = {
      "IgnoredUID"                      = "1337"
      "ProxyIngressPort"                = "15000"
      "ProxyEgressPort"                 = "15001"
      "AppPorts"                        = "${local.container_port}"
      "EgressIgnoredIPs"                = "169.254.170.2,169.254.169.254"
      "EgressIgnoredPorts"             = "22"
    }
  }

  tags = {
    Name        = "${var.environment}-${local.service_name}-taskdef"
    Environment = var.environment
    Module      = "booking-service"
  }
}

###############################################################################
# APPLICATION LOAD BALANCER (ALB)
# The booking service is exposed via HTTP (or HTTPS) using an ALB. This
# demonstrates a minimal ALB + target group + listener for traffic routing.
###############################################################################
resource "aws_lb" "booking_service" {
  name               = "${var.environment}-${local.service_name}-alb"
  load_balancer_type = "application"
  security_groups    = []
  subnets            = var.subnet_ids
  # If we want internet-facing, set 'internal = false', else true for private.
  internal           = false

  tags = {
    Name        = "${var.environment}-${local.service_name}-alb"
    Environment = var.environment
    Module      = "booking-service"
  }
}

# Target group for the ECS service
resource "aws_lb_target_group" "booking_service_tg" {
  name        = "${var.environment}-${local.service_name}-tg"
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  health_check {
    path                = local.health_check_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name        = "${var.environment}-${local.service_name}-tg"
    Environment = var.environment
    Module      = "booking-service"
  }
}

# Simple HTTP listener
resource "aws_lb_listener" "booking_service_listener" {
  load_balancer_arn = aws_lb.booking_service.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.booking_service_tg.arn
  }

  tags = {
    Name        = "${var.environment}-${local.service_name}-listener"
    Environment = var.environment
    Module      = "booking-service"
  }
}

###############################################################################
# CLOUD MAP / SERVICE DISCOVERY
# If we want the service to register into a private DNS namespace for internal
# discovery. This can also facilitate AWS App Mesh usage references.
###############################################################################
resource "aws_service_discovery_private_dns_namespace" "booking_namespace" {
  name        = "${var.environment}.local"
  description = "Private DNS namespace for the ${var.environment} environment"
  vpc         = var.vpc_id

  tags = {
    Name        = "${var.environment}-sd-namespace"
    Environment = var.environment
    Module      = "booking-service"
  }
}

resource "aws_service_discovery_service" "booking_service" {
  name = local.service_name
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.booking_namespace.id
    dns_records {
      type = "A"
      ttl  = 300
    }
    routing_policy = "MULTIVALUE"
  }

  tags = {
    Name        = "${local.service_name}-sd-service"
    Environment = var.environment
    Module      = "booking-service"
  }
}

###############################################################################
# CREATE THE ECS SERVICE
# This final piece ("create_ecs_service" from the spec) ties everything
# together: cluster, task definition, mesh config, load balancer, auto-scaling,
# deployment circuit breaker, and optional Cloud Map service discovery.
###############################################################################
resource "aws_ecs_service" "booking_service" {
  name            = "${var.environment}-${local.service_name}-service"
  cluster         = aws_ecs_cluster.booking_service_cluster.id
  task_definition = aws_ecs_task_definition.booking_service_task.arn
  desired_count   = local.desired_count
  launch_type     = "FARGATE"
  platform_version = "1.4.0"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = false  # or true if needed
    security_groups  = []
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.booking_service_tg.arn
    container_port   = local.container_port
    container_name   = local.service_name
  }

  service_registries {
    registry_arn = aws_service_discovery_service.booking_service.arn
  }

  deployment_controller {
    type = "ECS"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  health_check_grace_period_seconds = local.health_check_grace_period
  propagate_tags                    = "SERVICE"
  enable_execute_command            = true

  # Example for referencing the mesh. This is conceptual; real usage requires
  # referencing an "ALB Virtual Router" or "Virtual Node" for routing traffic.
  # We'll simply attach an optional tag here to illustrate mesh awareness.
  tags = {
    Name                 = "${var.environment}-${local.service_name}-service"
    Environment          = var.environment
    Module               = "booking-service"
    ServiceMeshAttached  = data.aws_appmesh_mesh.this.name
  }

  depends_on = [
    aws_lb_listener.booking_service_listener
  ]
}

###############################################################################
# APP AUTO SCALING: ALLOW THE SERVICE TO SCALE BASED ON CPU OR MEMORY
# We create a target on the ECS service's desiredCount, then attach multiple
# policies (e.g., CPU-based scaling, memory-based scaling).
###############################################################################
resource "aws_appautoscaling_target" "booking_service" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.booking_service_cluster.name}/${aws_ecs_service.booking_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = local.min_capacity
  max_capacity       = local.max_capacity
}

resource "aws_appautoscaling_policy" "booking_service_cpu" {
  name               = "${var.environment}-${local.service_name}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.booking_service.resource_id
  scalable_dimension = aws_appautoscaling_target.booking_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.booking_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 50.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "booking_service_memory" {
  name               = "${var.environment}-${local.service_name}-memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.booking_service.resource_id
  scalable_dimension = aws_appautoscaling_target.booking_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.booking_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = 50.0
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

###############################################################################
# FAKE DATA BLOCKS FOR DEMONSTRATION OF "MONGODB_CONNECTION_STRING" AND SECRET
# If referencing a remote state or a different module approach:
#
# data "terraform_remote_state" "database" {
#   backend = "s3"
#   config = {
#     bucket = "my-remote-state-bucket"
#     key    = "database/terraform.tfstate"
#     region = "us-east-1"
#   }
# }
#
# variable "mongodb_connection_string" {}
# variable "mongodb_secret_arn" {}
#
# For production usage, remove or adapt these examples as needed.
###############################################################################

###############################################################################
# OUTPUTS
# The JSON specification requires these five outputs for cross-module references
# or for the broader infrastructure to locate essential resource IDs and ARNs.
###############################################################################

# 1) ECS Cluster ARN
output "cluster_arn" {
  description = "ARN of the ECS cluster for the booking service"
  value       = aws_ecs_cluster.booking_service_cluster.arn
}

# 2) Service Name
output "service_name" {
  description = "Name of the booking ECS service"
  value       = local.service_name
}

# 3) Task Definition ARN
output "task_definition_arn" {
  description = "ARN of the booking service ECS task definition"
  value       = aws_ecs_task_definition.booking_service_task.arn
}

# 4) Service Discovery ARN (Cloud Map)
output "service_discovery_arn" {
  description = "ARN of the AWS Cloud Map service for booking"
  value       = aws_service_discovery_service.booking_service.arn
}

# 5) CloudWatch Log Group Name
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for booking service container logs"
  value       = aws_cloudwatch_log_group.booking_service_logs.name
}