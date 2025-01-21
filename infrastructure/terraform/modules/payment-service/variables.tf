###############################################################################
# Terraform Variables Definition File for Payment Service Module
# -----------------------------------------------------------------------------
# This file defines all configurable parameters required to deploy the
# Node.js-based payment microservice with enhanced security, scaling,
# and PCI DSS compliance features. The variables include validations
# to ensure production-ready configurations.
#
# Terraform Version: >= 1.6.0
###############################################################################

########################################################################
# ENVIRONMENT CONFIGURATION
########################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (dev/staging/prod) with strict validation to enforce correct usage in different lifecycle stages."

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

########################################################################
# SERVICE IDENTIFICATION
########################################################################
variable "service_name" {
  type        = string
  description = "Name of the payment service for resource identification, used for labeling and tagging across infrastructure."
  default     = "payment-service"
}

########################################################################
# CONTAINER AND APPLICATION SETTINGS
########################################################################
variable "container_image" {
  type        = string
  description = "Docker image URI for the payment service container. Must include a valid version tag for reproducible builds."
}

variable "container_port" {
  type        = number
  description = "Port exposed by the payment service container. Must be a valid port between 1 and 65535."
  default     = 3000

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "Container port must be between 1 and 65535."
  }
}

variable "desired_count" {
  type        = number
  description = "Desired number of container instances for high availability and load distribution."
  default     = 2

  validation {
    condition     = var.desired_count >= 2
    error_message = "Minimum 2 instances required for high availability."
  }
}

variable "cpu" {
  type        = number
  description = "CPU units for the container (1024 = 1 vCPU). Must be one of [256, 512, 1024, 2048]."
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048], var.cpu)
    error_message = "CPU units must be 256, 512, 1024, or 2048."
  }
}

variable "memory" {
  type        = number
  description = "Memory allocation for the container in MB. Must be between 512 and 4096 for stable performance."
  default     = 1024

  validation {
    condition     = var.memory >= 512 && var.memory <= 4096
    error_message = "Memory must be between 512 and 4096 MB."
  }
}

variable "health_check_path" {
  type        = string
  description = "HTTP path for container health checks. Ensures the application responds at a valid endpoint."
  default     = "/health"

  validation {
    condition     = can(regex("^/", var.health_check_path))
    error_message = "Health check path must start with '/'."
  }
}

########################################################################
# PAYMENT CONFIGURATIONS
########################################################################
variable "stripe_api_version" {
  type        = string
  description = "Stripe API version to maintain compatibility with Stripe's payment processing updates."
  default     = "2023-10-16"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.stripe_api_version))
    error_message = "Stripe API version must be in YYYY-MM-DD format."
  }
}

########################################################################
# AUTOSCALING CONFIGURATIONS
########################################################################
variable "autoscaling_min_capacity" {
  type        = number
  description = "Minimum number of container instances to maintain at all times, supporting fault tolerance and PCI DSS requirements."
  default     = 2

  validation {
    condition     = var.autoscaling_min_capacity >= 2
    error_message = "Minimum capacity must be at least 2 for high availability."
  }
}

variable "autoscaling_max_capacity" {
  type        = number
  description = "Maximum number of container instances for scaling out under peak loads."
  default     = 10

  validation {
    condition     = var.autoscaling_max_capacity >= var.autoscaling_min_capacity
    error_message = "Maximum capacity must be greater than or equal to minimum capacity."
  }
}

########################################################################
# LOGGING AND RETENTION
########################################################################
variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention period in days for audit and compliance tracking."
  default     = 30

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653],
      var.log_retention_days
    )
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

########################################################################
# NETWORK CONFIGURATION
########################################################################
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the payment service will be deployed, providing network isolation and security controls."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs used for encrypted communication and compliance within the VPC."
}

########################################################################
# SECURITY & COMPLIANCE
########################################################################
variable "enable_encryption" {
  type        = bool
  description = "Flag to enable at-rest encryption for PCI DSS compliance. Ensures sensitive payment data is properly protected."
  default     = true
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used for encryption, guaranteeing safe storage of sensitive information and cryptographic operations."
}

########################################################################
# TAGGING
########################################################################
variable "tags" {
  type        = map(string)
  description = "Key-value pairs for tagging AWS resources. Used for cost allocation, resource grouping, and environment identification."
  default     = {}
}