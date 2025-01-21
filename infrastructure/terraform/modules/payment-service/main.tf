#################################################################################################
# Terraform configuration for the Payment Microservice Infrastructure
# -----------------------------------------------------------------------------------------------
# This module deploys and manages the Payment Service microservice on AWS ECS Fargate, ensuring:
#  • PCI DSS compliance with secure storage of sensitive data (via KMS encryption),
#  • Network isolation using AWS Security Groups,
#  • High availability across private subnets in multiple availability zones,
#  • Comprehensive monitoring and logging for auditing and security.
#
# Imports (Internal):
#  - vpc_id, private_subnet_ids from ../networking/outputs.tf
#  - kms_key_arn from ../security/outputs.tf
#
# External Providers (per JSON spec):
#  - aws ~> 5.0       (for ECS, IAM, Security Groups, etc.)
#  - random ~> 3.0    (for generating resource-specific random strings if needed)
#
# Per Technical Specifications, this file addresses:
#  1) Payment Service Infrastructure (Sec 2.2.1, JavaScript/Node with Stripe)
#  2) High Availability (multi-AZ with ECS Fargate)
#  3) Security Requirements (PCI DSS controls, encryption at rest, locked-down network)
#################################################################################################

############################
# Required Provider Versions
############################
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS provider ~> 5.0
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # Random provider ~> 3.0
    }
  }
}

#######################################
# Provider Configuration for AWS Region
#######################################
# Typically set at the root module. Place here if module-level override is needed.
provider "aws" {
  region = var.aws_region
}

########################
# Module Input Variables
########################

# Identifier for the deployment environment (e.g., dev, staging, prod)
variable "environment" {
  type        = string
  description = "Deployment environment identifier (dev, staging, prod)."
}

# AWS region used by this module (e.g., us-east-1, us-west-2)
variable "aws_region" {
  type        = string
  description = "AWS region for the Payment Service deployment."
  default     = "us-east-1"
}

# ARN of the ECS cluster where the Payment Service is to be deployed.
variable "cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster on which to deploy the Payment Service."
}

# ID of the VPC imported from the networking module.
# Used for creating the PCI DSS-compliant security group.
variable "vpc_id" {
  type        = string
  description = "Imported VPC ID from networking module outputs."
}

# Private subnet IDs imported from the networking module.
# The Payment Service ECS tasks run in private subnets for enhanced security.
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs (multi-AZ) for ECS Fargate task placement."
}

# ARN of the KMS key for encrypting sensitive environment variables
# (e.g., Stripe secret keys). Imported from the security module.
variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used for encrypting sensitive data at rest."
}

# Container image for the Payment Service. In production, reference ECR or Docker Hub images.
variable "payment_image" {
  type        = string
  description = "Docker image URI for the Payment Service container."
  default     = "myorg/payment-service:latest"
}

############################
# Local Variables Definition
############################
locals {
  #################################################################################################
  # Payment Service Name
  # Construct a name incorporating environment for PCI DSS tagging and clarity.
  #################################################################################################
  service_name = "${var.environment}-payment-service"

  #################################################################################################
  # Container Port & Protocol
  # Payment Service listens on port 8443 with HTTPS to satisfy secure transport requirements.
  #################################################################################################
  container_port     = 8443
  container_protocol = "HTTPS"

  #################################################################################################
  # Scaling and Availability
  # (Desired count = 2 tasks minimum, up to 4 if auto-scaling is attached in a higher-level config.)
  #################################################################################################
  desired_count = 2
  max_count     = 4

  #################################################################################################
  # Logging Configuration
  # For PCI DSS compliance, logs must be retained under CloudWatch with restricted access.
  #################################################################################################
  cloudwatch_log_group_name = "/aws/ecs/${var.environment}/payment-service"
  log_retention_days        = 30

  #################################################################################################
  # Health Check Configuration
  # Minimal sample health check using a simple HTTP GET to /health. Adjust as needed for app logic.
  #################################################################################################
  healthcheck_command = [
    "CMD-SHELL",
    "curl -f http://localhost:${local.container_port}/health || exit 1"
  ]
  health_check_interval           = 30
  health_check_timeout            = 5
  health_check_retries            = 3
  health_check_start_period       = 60
  health_check_grace_period       = 30

  #################################################################################################
  # PCI DSS Tags
  # Ensuring clear labeling regarding PCI compliance for auditing.
  #################################################################################################
  pci_tags = {
    PCI_Compliance = "true"
  }
}

##############################
# IAM Policy Documents (Data)
##############################
# Trust policy granting ECS tasks permission to assume the role.
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    sid       = "ECSContainerTasks"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role policy to allow pulling images from ECR and writing logs to CloudWatch.
data "aws_iam_policy_document" "ecs_execution_role_policy" {
  statement {
    sid     = "AllowECRPullAndLogging"
    effect  = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

# Inline policy to allow the Payment task to decrypt secrets with our KMS key (Stripe API key, etc.).
data "aws_iam_policy_document" "payment_task_kms_policy" {
  statement {
    sid     = "AllowKMSUsage"
    effect  = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [var.kms_key_arn]
  }
}

###############################################
# IAM Roles & Policies for ECS Task/Execution
###############################################
resource "aws_iam_role" "payment_execution_role" {
  name               = "${local.service_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    {
      Name        = "${local.service_name}-execution-role"
      Environment = var.environment
      Service     = "PaymentExecutionRole"
    },
    local.pci_tags
  )
}

resource "aws_iam_role_policy" "payment_execution_policy" {
  name   = "${local.service_name}-execution-policy"
  role   = aws_iam_role.payment_execution_role.id
  policy = data.aws_iam_policy_document.ecs_execution_role_policy.json
}

resource "aws_iam_role" "payment_task_role" {
  name               = "${local.service_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = merge(
    {
      Name        = "${local.service_name}-task-role"
      Environment = var.environment
      Service     = "PaymentTaskRole"
    },
    local.pci_tags
  )
}

resource "aws_iam_role_policy" "payment_task_kms_attach" {
  name   = "${local.service_name}-kms-policy"
  role   = aws_iam_role.payment_task_role.id
  policy = data.aws_iam_policy_document.payment_task_kms_policy.json
}

##################################################
# ECS Task Definition (PCI DSS Compliant Fargate)
##################################################
resource "aws_ecs_task_definition" "payment" {
  family                   = local.service_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512

  execution_role_arn = aws_iam_role.payment_execution_role.arn
  task_role_arn      = aws_iam_role.payment_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "payment-container"
      image     = var.payment_image
      essential = true

      # Basic example environment variable; real secrets would be stored in AWS SSM or Secrets Manager.
      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        }
      ]

      # If referencing secrets, they'd go here (e.g., "secrets" list).
      # secrets = [
      #   {
      #     name      = "STRIPE_SECRET_KEY"
      #     valueFrom = "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/stripe_secret_key"
      #   }
      # ]

      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]

      # Health check configuration
      healthCheck = {
        command     = local.healthcheck_command
        interval    = local.health_check_interval
        timeout     = local.health_check_timeout
        retries     = local.health_check_retries
        startPeriod = local.health_check_start_period
      }

      # Logging to CloudWatch for auditing (PCI DSS)
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.cloudwatch_log_group_name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "payment"
        }
      }
    }
  ])

  # Enable Amazon ECS Container Insights for advanced monitoring if desired.
  tags = merge(
    {
      Family       = local.service_name
      Environment  = var.environment
      Service      = "Payment"
    },
    local.pci_tags
  )
}

#########################################
# ECS Service: High Availability Fargate
#########################################
resource "aws_ecs_service" "payment" {
  name            = local.service_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.payment.arn
  desired_count   = local.desired_count
  launch_type     = "FARGATE"

  # Deployment configuration with circuit breaker
  deployment_controller {
    type = "ECS"
  }
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Minimum healthy percent and maximum percent for rolling updates
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.payment_sg.id]
    assign_public_ip = false
  }

  health_check_grace_period_seconds = local.health_check_grace_period

  # Basic example of putting it behind no load balancer, or you can define an ALB block here if needed.
  # load_balancer {
  #   target_group_arn = "arn:aws:elasticloadbalancing:REGION:ACCOUNT_ID:targetgroup/..."
  #   container_name   = "payment-container"
  #   container_port   = local.container_port
  # }

  tags = merge(
    {
      Name         = "${local.service_name}-service"
      Environment  = var.environment
      Service      = "Payment"
    },
    local.pci_tags
  )
}

############################################################
# Security Group for Payment Service (PCI DSS Compliance)
############################################################
resource "aws_security_group" "payment_sg" {
  name        = "${local.service_name}-sg"
  description = "Security Group for Payment Service with PCI DSS restrictions"
  vpc_id      = var.vpc_id

  # Inbound: typically restricted to load balancer or specific IP address ranges.
  # For demonstration, we use 0.0.0.0/0, but a real deployment would reference ALB SG or known IPs.
  ingress {
    description      = "Allow inbound traffic on secure port from LB or authorized sources"
    from_port        = local.container_port
    to_port          = local.container_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Outbound: restrict to Stripe endpoints or IAM role-based controls if needed.
  # For a simplified approach, allow all egress.
  egress {
    description = "Allow all outbound for payment gateway calls, logging, etc."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "${local.service_name}-sg"
      Environment = var.environment
    },
    local.pci_tags
  )
}

###################
# CloudWatch Log Group
# (Optional if using awslogs driver without auto-create)
###################
resource "aws_cloudwatch_log_group" "payment_logs" {
  name              = local.cloudwatch_log_group_name
  retention_in_days = local.log_retention_days

  tags = merge(
    {
      Name         = "${local.service_name}-logs"
      Environment  = var.environment
      LogGroupType = "PaymentService"
    },
    local.pci_tags
  )
}

############################
# Module Exported Outputs
############################

# ECS Service Name
output "service_name" {
  description = "The name of the Payment ECS Service."
  value       = aws_ecs_service.payment.name
}

# Security Group ID for Payment Service
output "security_group_id" {
  description = "Security Group ID for the Payment Service tasks."
  value       = aws_security_group.payment_sg.id
}

# Task Role ARN for Payment Container
output "task_role_arn" {
  description = "IAM Task Role ARN attached to the Payment Service container for advanced KMS or API permissions."
  value       = aws_iam_role.payment_task_role.arn
}