###############################################################################
# Variable: environment
# Purpose: Identifies the deployment environment for tagging, naming, and
#          environment-specific configurations (e.g., dev/staging/prod).
###############################################################################
variable "environment" {
  type        = string
  description = "Environment name for resource tagging and naming with validation for allowed values."

  # Enforce only specific values (e.g., dev, staging, prod) to maintain consistency
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Invalid environment. Must be one of: dev, staging, or prod."
  }
}

###############################################################################
# Variable: aws_region
# Purpose: AWS region where the notification service is deployed, validated
#          against typical region patterns like us-east-1, us-west-2, etc.
###############################################################################
variable "aws_region" {
  type        = string
  description = "AWS region for deploying notification service resources with format validation."

  # Basic check ensuring the region string follows a standard pattern
  validation {
    condition     = can(regex("^(us|af|ap|ca|eu|me|sa)-[a-z0-9-]+-\\d+$", var.aws_region))
    error_message = "Invalid AWS region format. Example of a valid format: us-east-1."
  }
}

###############################################################################
# Variable: vpc_id
# Purpose: The VPC ID within which to deploy the notification service. Ensures
#          the ID follows AWS vpc-xxxxxx formatting.
###############################################################################
variable "vpc_id" {
  type        = string
  description = "VPC ID where notification service will be deployed with format validation."

  # Validate against typical VPC ID pattern
  validation {
    condition     = can(regex("^vpc-([0-9a-f]{8}|[0-9a-f]{17})$", var.vpc_id))
    error_message = "Invalid VPC ID. Must match the pattern \"vpc-xxxxxxxx\" or \"vpc-xxxxxxxxxxxxxxxxx\"."
  }
}

###############################################################################
# Variable: private_subnet_ids
# Purpose: List of private subnet IDs in which tasks will be placed, ensuring
#          multi-AZ distribution for high availability.
###############################################################################
variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for multi-AZ notification service deployment."

  # Ensure list is not empty and each entry matches AWS subnet ID patterns
  validation {
    condition = length(var.private_subnet_ids) > 0
      && alltrue([
        for subnet_id in var.private_subnet_ids :
        can(regex("^subnet-[0-9a-f]{8,17}$", subnet_id))
      ])
    error_message = "All private_subnet_ids must match the pattern \"subnet-xxxxxxxx\" or \"subnet-xxxxxxxxxxxxxxxxx\" and cannot be empty."
  }
}

###############################################################################
# Variable: cluster_id
# Purpose: The ECS cluster ID on which the notification service will run.
###############################################################################
variable "cluster_id" {
  type        = string
  description = "ECS cluster ID where notification service will run."
}

###############################################################################
# Variable: task_cpu
# Purpose: Defines the CPU units for the container task. Must be compatible with
#          AWS Fargate CPU configurations.
###############################################################################
variable "task_cpu" {
  type        = number
  description = "CPU units for notification service task definition with Fargate compatibility validation."
  default     = 256

  # Restricting to Fargate-compatible values
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Invalid CPU value. Must be one of [256, 512, 1024, 2048, 4096] for Fargate."
  }
}

###############################################################################
# Variable: task_memory
# Purpose: Allocates memory for the container task. Must be within valid
#          Fargate constraints (e.g., 512MB to 30720MB).
###############################################################################
variable "task_memory" {
  type        = number
  description = "Memory units for notification service task definition with Fargate compatibility validation."
  default     = 512

  # Basic range check for typical Fargate memory limits
  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 30720
    error_message = "Memory must be between 512 and 30720 MB to be Fargate-compatible."
  }
}

###############################################################################
# Variable: container_port
# Purpose: The container port on which the notification service listens.
#          Must lie within the allowable TCP/UDP port range (1-65535).
###############################################################################
variable "container_port" {
  type        = number
  description = "Container port for notification service with valid port range validation."
  default     = 8080

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "Container port must be between 1 and 65535."
  }
}

###############################################################################
# Variable: desired_count
# Purpose: Specifies how many copies of the notification service task to run,
#          ensuring high availability and load distribution.
###############################################################################
variable "desired_count" {
  type        = number
  description = "Desired number of notification service tasks for high availability."
  default     = 2

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 10
    error_message = "Desired task count must be between 1 and 10."
  }
}

###############################################################################
# Variable: email_config
# Purpose: Holds SendGrid email configuration for multi-channel notifications.
#          This includes the API key for sending emails and other relevant
#          settings. Marked as sensitive for security.
###############################################################################
variable "email_config" {
  type        = map(string)
  description = "SendGrid email service configuration with API key and sender settings."
  sensitive   = true

  # Ensure required keys (e.g., api_key, sender_email) are present and valid
  validation {
    condition = alltrue([
      contains(keys(var.email_config), "api_key"),
      contains(keys(var.email_config), "sender_email"),
      can(regex("^[^@]+@[^@]+\\.[^@]+$", var.email_config["sender_email"]))
    ])
    error_message = "email_config must include 'api_key' and a valid 'sender_email'."
  }
}

###############################################################################
# Variable: push_config
# Purpose: Contains FCM/APNs credentials for push notifications. Ensures that
#          at least one relevant key is provided. Marked sensitive to protect
#          authentication secrets.
###############################################################################
variable "push_config" {
  type        = map(string)
  description = "Firebase FCM and APNs push notification configuration with credentials."
  sensitive   = true

  # Either 'fcm_api_key' or 'apns_auth_key' must be present
  validation {
    condition = anytrue([
      contains(keys(var.push_config), "fcm_api_key"),
      contains(keys(var.push_config), "apns_auth_key")
    ])
    error_message = "push_config must include 'fcm_api_key' or 'apns_auth_key' for push notifications."
  }
}

###############################################################################
# Variable: sms_config
# Purpose: AWS SNS SMS configuration, including a sender ID or necessary
#          details for sending SMS messages. Marked as sensitive to avoid
#          exposing credentials.
###############################################################################
variable "sms_config" {
  type        = map(string)
  description = "AWS SNS SMS configuration with sender ID and delivery settings."
  sensitive   = true

  # Must include at least 'sender_id'
  validation {
    condition     = contains(keys(var.sms_config), "sender_id")
    error_message = "sms_config must include 'sender_id'."
  }
}

###############################################################################
# Variable: tags
# Purpose: Resource tags for the notification service under best practices,
#          allowing optional custom tagging. Defaults to an empty map.
###############################################################################
variable "tags" {
  type        = map(string)
  description = "Resource tags for notification service components with default values."
  default     = {}
}