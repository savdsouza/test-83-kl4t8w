###############################################################################
# Terraform Configuration Block
###############################################################################
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
  }
}

###############################################################################
# Variable: environment
# Description: Deployment environment (development/staging/production).
# Validation ensures strict adherence to valid environment names.
# Reference: System Requirements 7.1 (Authentication & Authorization) for
# environment-based security policies.
###############################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (development/staging/production)."

  validation {
    condition     = can(regex("^(development|staging|production)$", var.environment))
    error_message = "Environment must be development, staging, or production."
  }
}

###############################################################################
# Variable: aws_region
# Description: AWS region for deploying the auth service.
# Default: us-east-1
# Reference: High Availability Architecture 8.2.2 for multi-region strategy.
###############################################################################
variable "aws_region" {
  type        = string
  description = "AWS region for deploying the auth service."
  default     = "us-east-1"
}

###############################################################################
# Variable: service_name
# Description: Name of the authentication service for resource tagging
# and identification.
# Default: auth-service
###############################################################################
variable "service_name" {
  type        = string
  description = "Name of the authentication service."
  default     = "auth-service"
}

###############################################################################
# Variable: container_config
# Description: Container configuration settings for the auth service.
# Includes references to container port, CPU, memory, and environment variables.
# Reference: System Architecture - provisioning container-based microservices.
###############################################################################
variable "container_config" {
  type = object({
    image                 = string
    port                  = number
    cpu                   = number
    memory                = number
    health_check_path     = string
    environment_variables = map(string)
  })

  description = <<EOD
Container configuration settings, including:
- image: Docker image (e.g., some-registry/organization/auth-service:latest)
- port: Container port for the service
- cpu: CPU units for the container
- memory: Memory in MB for the container
- health_check_path: Path for container health checks
- environment_variables: Key-value map for environment variables
EOD

  default = {
    image                 = "some-registry/organization/auth-service:latest"
    port                  = 3000
    cpu                   = 1024
    memory                = 2048
    health_check_path     = "/health"
    environment_variables = {}
  }
}

###############################################################################
# Variable: database_config
# Description: Enhanced database configuration with security settings,
# reflecting Data Security (7.2) and HA approach (8.2.2).
###############################################################################
variable "database_config" {
  type = object({
    engine                   = string
    engine_version           = string
    instance_class           = string
    allocated_storage        = number
    max_allocated_storage    = number
    backup_retention_period  = number
    multi_az                 = bool
    deletion_protection      = bool
    encryption_enabled       = bool
    kms_key_id               = string
    performance_insights_enabled = bool
    audit_logging_enabled    = bool
  })

  description = <<EOD
Database configuration for the authentication service, covering:
- engine / engine_version: Type of DB engine and its version
- instance_class: DB instance size
- allocated_storage / max_allocated_storage: Initial and max storage
- backup_retention_period: Days to retain backups
- multi_az: Ensures availability across multiple AZs
- deletion_protection: Prevents accidental database deletion
- encryption_enabled / kms_key_id: At-rest encryption and KMS key usage
- performance_insights_enabled: Enables Performance Insights
- audit_logging_enabled: Enables advanced audit logging
EOD

  default = {
    engine                   = "aurora-postgresql"
    engine_version           = "15.3"
    instance_class           = "db.r6g.large"
    allocated_storage        = 20
    max_allocated_storage    = 100
    backup_retention_period  = 7
    multi_az                 = true
    deletion_protection      = true
    encryption_enabled       = true
    kms_key_id               = ""
    performance_insights_enabled = true
    audit_logging_enabled    = true
  }
}

###############################################################################
# Variable: auth_config
# Description: Enhanced authentication service configuration to address
# requirements in 7.1 (Authentication and Authorization) and Data Security (7.2).
###############################################################################
variable "auth_config" {
  type = object({
    jwt_config = object({
      expiry               = string
      refresh_token_expiry = string
      algorithm            = string
      issuer               = string
    })
    password_policy = object({
      min_length         = number
      require_uppercase  = bool
      require_lowercase  = bool
      require_numbers    = bool
      require_symbols    = bool
      password_history   = number
    })
    mfa_config = object({
      enabled           = bool
      methods           = list(string)
      enforcement_level = string
    })
    oauth_config = object({
      providers     = list(string)
      callback_urls = list(string)
    })
    biometric_config = object({
      enabled         = bool
      allowed_methods = list(string)
    })
  })

  description = <<EOD
Authentication configuration, including:
- jwt_config: Token expiry, refresh token expiry, signing algorithm, issuer
- password_policy: Password length, complexity requirements, and history
- mfa_config: Multi-factor authentication enablement and enforcement
- oauth_config: OAuth providers and callback URLs
- biometric_config: Biometric-based authentication methods
EOD

  default = {
    jwt_config = {
      expiry               = "15m"
      refresh_token_expiry = "7d"
      algorithm            = "RS256"
      issuer               = "dog-walking-app"
    }
    password_policy = {
      min_length         = 12
      require_uppercase  = true
      require_lowercase  = true
      require_numbers    = true
      require_symbols    = true
      password_history   = 5
    }
    mfa_config = {
      enabled           = true
      methods           = ["TOTP", "SMS", "EMAIL"]
      enforcement_level = "required"
    }
    oauth_config = {
      providers     = ["google", "apple", "facebook"]
      callback_urls = []
    }
    biometric_config = {
      enabled         = true
      allowed_methods = ["FINGERPRINT", "FACE_ID", "TOUCH_ID"]
    }
  }
}

###############################################################################
# Variable: scaling_config
# Description: Enhanced auto-scaling configuration, aligning with high
# availability (8.2.2) and performance needs.
###############################################################################
variable "scaling_config" {
  type = object({
    min_capacity             = number
    max_capacity             = number
    target_cpu_utilization   = number
    target_memory_utilization = number
    scale_in_cooldown        = number
    scale_out_cooldown       = number
    custom_metrics           = list(object({
      metric_name  = string
      target_value = number
    }))
  })

  description = <<EOD
Auto-scaling configuration:
- min_capacity / max_capacity: ECS tasks range
- target_cpu_utilization / target_memory_utilization: Scaling thresholds
- scale_in_cooldown / scale_out_cooldown: Cooldown periods (seconds)
- custom_metrics: Optional advanced metrics for scaling
EOD

  default = {
    min_capacity             = 2
    max_capacity             = 10
    target_cpu_utilization   = 70
    target_memory_utilization = 80
    scale_in_cooldown        = 300
    scale_out_cooldown       = 180
    custom_metrics           = []
  }
}

###############################################################################
# Variable: security_config
# Description: Security configuration for WAF, AWS Shield, SSL policies, and
# security group settings, referencing 7.2 Data Security.
###############################################################################
variable "security_config" {
  type = object({
    waf_enabled            = bool
    shield_advanced_enabled = bool
    ssl_policy             = string
    security_group_rules   = list(object({
      type        = string
      from_port   = number
      to_port     = number
      cidr_blocks = list(string)
    }))
    vpc_endpoint_services = list(string)
  })

  description = <<EOD
Security provisions:
- waf_enabled / shield_advanced_enabled: Protection against web threats and DDoS
- ssl_policy: TLS/SSL security policy for load balancer
- security_group_rules: List of inbound/outbound rules with ports and CIDRs
- vpc_endpoint_services: Private link services such as Secrets Manager, KMS, logs
EOD

  default = {
    waf_enabled            = true
    shield_advanced_enabled = true
    ssl_policy             = "ELBSecurityPolicy-TLS-1-2-2017-01"
    security_group_rules   = []
    vpc_endpoint_services  = ["secretsmanager", "kms", "logs"]
  }
}

###############################################################################
# Variable: monitoring_config
# Description: Monitoring and logging configuration, ensuring compliance
# with security and audit controls (7.2 Data Security).
###############################################################################
variable "monitoring_config" {
  type = object({
    log_retention_days  = number
    enable_trace_logging = bool
    enable_audit_logging = bool
    alarm_notification_arn = string
  })

  description = <<EOD
Monitoring & logging settings:
- log_retention_days: Number of days to retain logs
- enable_trace_logging: Enable distributed tracing and request logging
- enable_audit_logging: Activates advanced audit logs
- alarm_notification_arn: SNS or other ARN for sending critical alarms
EOD

  default = {
    log_retention_days   = 90
    enable_trace_logging = true
    enable_audit_logging = true
    alarm_notification_arn = ""
  }
}

###############################################################################
# Variable: vpc_id
# Description: ID of the VPC where the auth service will be deployed.
###############################################################################
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the auth service will be deployed."
}

###############################################################################
# Variable: private_subnet_ids
# Description: List of private subnet IDs used by the auth service for internal
# communication, aligning with best practices for security (7.2).
###############################################################################
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for the service."
}

###############################################################################
# Variable: tags
# Description: Map of tags to apply to all resources, ensuring consistent
# resource identification and compliance with organizational standards.
###############################################################################
variable "tags" {
  type        = map(string)
  description = "Tags to be applied to all resources."
  default = {
    Service   = "auth-service"
    ManagedBy = "terraform"
  }
}