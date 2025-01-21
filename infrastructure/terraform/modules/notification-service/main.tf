###############################################################################
# Terraform configuration for the Notification Service module on AWS ECS Fargate
# ==============================================================================
# This file implements a Python-based notification service capable of
# handling multi-channel notifications (push, email, and SMS) with the
# following key objectives:
# 1. High Availability: Multi-AZ deployment, health checks, and auto-scaling
# 2. Security: Secrets management via AWS Secrets Manager, locked-down security
#    groups, and encryption in transit via AWS ECS and IAM roles
# 3. Container Orchestration: Fargate-based tasks with consistent CPU and
#    memory configurations, plus target-tracking auto-scaling for CPU/memory
# 4. Service Discovery: AWS Cloud Map integration for container service
#    registration/resolution
# 5. Logging & Monitoring: AWSLogs driver for CloudWatch Log Group integration
# 
# This module references:
# - HashiCorp AWS Provider (version ~> 4.16.0)
# - HashiCorp Random Provider (version ~> 3.4.0)
# - Internal variables defined in variables.tf
###############################################################################

###############################################################################
# Terraform Settings & Provider Requirements
# Enforces minimum Terraform version, as well as pinned provider versions.
###############################################################################
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0" # hashicorp/aws (version ~> 4.16.0)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.0" # hashicorp/random (version ~> 3.4.0)
    }
  }
}

###############################################################################
# Local Values
# -----------------------------------------------------------------------------
# 1. service_name: Unique name for ECS tasks/services, suffixed by environment
# 2. container_name: Internal container name used within the ECS task definition
# 3. log_group_name: Path for CloudWatch log group references
# 4. tags: Merged map of custom and mandatory tags for all resources
###############################################################################
locals {
  service_name   = "notification-service-${var.environment}"
  container_name = "notification-service"

  # Log group name to centralize logs by environment
  log_group_name = "/ecs/notification-service/${var.environment}"

  # Merge user-defined tags with mandatory tags: includes environment, service,
  # and marker for Terraform management
  tags = merge(
    var.tags,
    {
      Service     = "notification-service-${var.environment}"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  )
}

###############################################################################
# (Optional) Data Sources for AWS Secrets Manager
# -----------------------------------------------------------------------------
# These data references retrieve the ARNs of existing Secrets Manager secrets
# for SMTP (Email), FCM (Push), and SMS credentials. The 'name' attribute must
# match the actual secret name created externally or in another module.
#
# If these secrets are not yet provisioned, consider creating corresponding
# resources or data blocks in an external or higher-level module.
###############################################################################
data "aws_secretsmanager_secret" "smtp" {
  name = "smtp-credentials"
}

data "aws_secretsmanager_secret" "fcm" {
  name = "fcm-credentials"
}

data "aws_secretsmanager_secret" "sms" {
  name = "sms-credentials"
}

###############################################################################
# (Optional) IAM Role Variables
# -----------------------------------------------------------------------------
# These corresponds to the ECS Execution Role (pull images, write logs) and
# ECS Task Role (in-container permissions). They should be defined or passed
# in from a higher-level module or root configuration.
###############################################################################
variable "ecs_execution_role_arn" {
  type        = string
  description = "ARN of IAM role for ECS agent execution (pulling images, logging)."
}

variable "ecs_task_role_arn" {
  type        = string
  description = "ARN of IAM role for the ECS task (in-container privileges)."
}

###############################################################################
# (Optional) Container Image Variable
# -----------------------------------------------------------------------------
# This ensures the container image can be explicitly provided for versioning
# or environment-based deployments. The image must be stored in a repository
# accessible to ECS (e.g., ECR, Docker Hub, or another external registry).
###############################################################################
variable "container_image" {
  type        = string
  description = "Docker image used by the notification service container."
}

###############################################################################
# Additional Variables for Auto Scaling and Service Discovery
# -----------------------------------------------------------------------------
# cluster_name: Name of the ECS cluster (e.g., my-ecs-cluster). Used to build
#               the resource_id for target tracking scaling.
# min_capacity, max_capacity: Auto-scaling limits to ensure enough capacity
#                             for load while avoiding unwanted cost spikes.
# service_discovery_arn: Optional variable referencing an AWS Service Discovery
#                        service in Cloud Map. If not needed, pass an empty
#                        string or handle conditionally in root module.
###############################################################################
variable "cluster_name" {
  type        = string
  description = "Name of the ECS cluster used for the resource_id in App AutoScaling."
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of ECS tasks for the notification service."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of ECS tasks for the notification service."
  default     = 5
}

variable "service_discovery_arn" {
  type        = string
  description = "ARN of the AWS Service Discovery service for container service registry."
  default     = ""
}

###############################################################################
# Resource: AWS ECS Task Definition (notification)
# -----------------------------------------------------------------------------
# This resource defines how the container(s) will operate within a task,
# including CPU/memory resources, network mode, container images, environment
# variables, secrets, and health checks. Fargate compatibility is enforced
# by requires_compatibilities and network_mode set to 'awsvpc'.
###############################################################################
resource "aws_ecs_task_definition" "notification" {
  family                   = local.service_name
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  # IAM roles: ECS execution for pulling images/logging, ECS task for in-container
  # AWS permissions such as reading/writing to S3, SNS, etc.
  execution_role_arn = var.ecs_execution_role_arn
  task_role_arn      = var.ecs_task_role_arn

  # Container definitions inlined as JSON. These specify container health checks,
  # secret references for SMTP, FCM, and SMS credentials, plus logging config.
  container_definitions = <<DEFINITION
[
  {
    "name": "${local.container_name}",
    "image": "${var.container_image}",
    "essential": true,
    "healthCheck": {
      "command": ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"],
      "interval": 30,
      "timeout": 5,
      "retries": 3,
      "startPeriod": 60
    },
    "secrets": [
      {
        "name": "SMTP_PASSWORD",
        "valueFrom": "${data.aws_secretsmanager_secret.smtp.arn}"
      },
      {
        "name": "FCM_KEY",
        "valueFrom": "${data.aws_secretsmanager_secret.fcm.arn}"
      },
      {
        "name": "SMS_API_KEY",
        "valueFrom": "${data.aws_secretsmanager_secret.sms.arn}"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${local.log_group_name}",
        "awslogs-region": "${var.aws_region}",
        "awslogs-stream-prefix": "ecs"
      }
    },
    "portMappings": [
      {
        "containerPort": ${var.container_port},
        "hostPort": ${var.container_port},
        "protocol": "tcp"
      }
    ]
  }
]
DEFINITION
}

###############################################################################
# Resource: AWS ECS Service (notification)
# -----------------------------------------------------------------------------
# An ECS service that runs the task definition above, distributing tasks across
# private subnets for high availability. The deployment_minimum_healthy_percent
# and deployment_maximum_percent control the number of healthy tasks during
# updates. 'service_registries' associates the service with AWS Cloud Map for
# easy discovery if required.
###############################################################################
resource "aws_ecs_service" "notification" {
  name                               = local.service_name
  cluster                            = var.cluster_id
  task_definition                    = aws_ecs_task_definition.notification.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  health_check_grace_period_seconds  = 60
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  # Assign tasks across private subnets and use a security group to restrict
  # traffic. assign_public_ip=false ensures these tasks only receive private IPs.
  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.notification.id]
    assign_public_ip = false
  }

  # Optionally integrate with AWS Service Discovery. If 'service_discovery_arn'
  # is blank, consider conditionals or pass in a valid ARN. This block sets up
  # container-based service discovery for the specified container/port.
  service_registries {
    registry_arn   = var.service_discovery_arn
    container_name = local.container_name
    container_port = var.container_port
  }

  tags = local.tags
}

###############################################################################
# Resource: AWS App AutoScaling Target (notification)
# -----------------------------------------------------------------------------
# Attaches the ECS service as a scalable target for adjusting desired_count based
# on CPU or memory usage. By specifying resource_id as "service/<cluster_name>/<service_name>",
# we link this ECS service for dynamic scaling.
###############################################################################
resource "aws_appautoscaling_target" "notification" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.notification.name}"
  scalable_dimension = "ecs:service:DesiredCount"

  min_capacity = var.min_capacity
  max_capacity = var.max_capacity
}

###############################################################################
# Resource: AWS App AutoScaling Policies (notification - CPU & Memory)
# -----------------------------------------------------------------------------
# Each policy references the scalable target above. Target tracking is used to
# auto-scale tasks up/down based on ECSServiceAverageCPUUtilization or
# ECSServiceAverageMemoryUtilization. It enforces cooldowns to avoid thrashing.
###############################################################################
resource "aws_appautoscaling_policy" "notification_cpu" {
  name               = "${local.service_name}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.notification.resource_id
  scalable_dimension = aws_appautoscaling_target.notification.scalable_dimension
  service_namespace  = aws_appautoscaling_target.notification.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.notification]
}

resource "aws_appautoscaling_policy" "notification_memory" {
  name               = "${local.service_name}-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.notification.resource_id
  scalable_dimension = aws_appautoscaling_target.notification.scalable_dimension
  service_namespace  = aws_appautoscaling_target.notification.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 80.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }

  depends_on = [aws_appautoscaling_target.notification]
}

###############################################################################
# Resource: AWS Security Group (notification)
# -----------------------------------------------------------------------------
# Security group that only allows inbound traffic on the container port from
# the specified CIDR blocks and permits all outbound traffic. By default,
# container_port is 8080 unless overridden. This ensures that the container
# port is the only externally accessible port.
###############################################################################
resource "aws_security_group" "notification" {
  name        = local.service_name
  description = "Security Group for the Notification Service"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    cidr_blocks     = var.allowed_cidr_blocks
    description     = "Service port access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.tags
}

###############################################################################
# EXPORTS / OUTPUTS
# -----------------------------------------------------------------------------
# Provide references to ECS task definitions, services, and auto-scaling targets.
# These outputs enable other modules or root configuration to integrate with
# the deployed resources, e.g., hooking into CI/CD or aggregator modules.
###############################################################################

output "ecs_task_definition_notification" {
  description = "ARN of the ECS Task Definition for the notification service"
  value       = aws_ecs_task_definition.notification.arn
}

output "ecs_service_notification_id" {
  description = "ID of the ECS service resource for the notification service"
  value       = aws_ecs_service.notification.id
}

output "appautoscaling_target_notification" {
  description = "Auto-scaling target attributes for the ECS notification service"
  value = {
    resource_id        = aws_appautoscaling_target.notification.resource_id
    scalable_dimension = aws_appautoscaling_target.notification.scalable_dimension
    service_namespace  = aws_appautoscaling_target.notification.service_namespace
  }
}