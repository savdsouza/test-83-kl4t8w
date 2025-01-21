###############################################################################
# Root-level Terraform Variables Definition File
# -----------------------------------------------------------------------------
# This file configures global settings and shared variables used across all
# infrastructure modules for the Dog Walking Platform. It directly supports:
# - Multi-Region Deployment  (Primary: us-east-1, Secondary: us-west-2)
# - High Availability        (Auto-scaling, multi-AZ, cross-region failover)
# - Infrastructure Security  (Encryption, monitoring, threat detection, compliance)
#
# References:
# - Technical Specification Sections:
#   2.5 Deployment Architecture (Multi-Region, High Availability)
#   7.3 Security Protocols (Encryption/Monitoring/Compliance)
#
# Imports and Globals:
# - Utilizes AWS Provider configuration from provider.tf (alias primary/secondary)
# - Includes "project_name" for consistent resource naming and tagging
###############################################################################

###############################################################################
# Local Values
###############################################################################
locals {
  # Global project name used for resource naming and tagging throughout the ecosystem
  project_name = "dog-walking-platform"
}

###############################################################################
# Environment Variable
# -----------------------------------------------------------------------------
# Defines the current deployment environment. Must be one of: dev, staging, prod.
# This is critical for the platform to differentiate resource naming, lifecycle
# policies, and scaling factors across multiple environments.
###############################################################################
variable "environment" {
  type        = string
  description = <<-EOT
Specifies the deployment environment (e.g., dev, staging, or prod).
Must adhere to strict validation for consistent naming and operational controls.
EOT

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod"
  }
}

###############################################################################
# AWS Regions Configuration
# -----------------------------------------------------------------------------
# Provides the primary and secondary AWS regions for multi-region deployment
# with cross-region replication and failover. By default, we use us-east-1 and
# us-west-2 to satisfy High Availability requirements.
###############################################################################
variable "aws_regions" {
  type = object({
    primary   = string
    secondary = string
  })

  description = <<-EOT
Defines the AWS regions for multi-region architecture. 'primary' hosts the main
infrastructure, while 'secondary' supports failover and DR. Both must be among
["us-east-1", "us-west-2"] for the current phase of multi-region scaling.
EOT

  default = {
    primary   = "us-east-1"
    secondary = "us-west-2"
  }

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_regions.primary)
                && contains(["us-east-1", "us-west-2"], var.aws_regions.secondary)
    error_message = "Only us-east-1 and us-west-2 regions are supported"
  }
}

###############################################################################
# VPC Configuration
# -----------------------------------------------------------------------------
# Provides CIDR block and toggles for VPC flow logs and endpoints for secure
# network isolation. Flow logs help with monitoring and security compliance,
# while endpoints enable private connectivity to AWS services.
###############################################################################
variable "vpc_configuration" {
  type = object({
    cidr             = string
    enable_flow_logs = bool
    enable_endpoints = bool
  })

  description = <<-EOT
Specifies the VPC network configuration. Includes the primary CIDR block, flow
logs (for auditing network traffic), and endpoints (for secure, private access
to AWS services).
EOT

  default = {
    cidr             = "10.0.0.0/16"
    enable_flow_logs = true
    enable_endpoints = true
  }

  validation {
    condition     = can(cidrhost(var.vpc_configuration.cidr, 0))
    error_message = "Invalid CIDR block format"
  }
}

###############################################################################
# Security Controls Configuration
# -----------------------------------------------------------------------------
# Enables or disables global security services such as encryption, GuardDuty,
# CloudTrail, and Security Hub. These services collectively help protect and
# monitor the platform against threats, ensuring compliance and audit readiness.
###############################################################################
variable "security_controls" {
  type = object({
    encryption  = bool
    guardduty   = bool
    cloudtrail  = bool
    securityhub = bool
  })

  description = <<-EOT
Global security configuration. Toggles encryption at rest (KMS), AWS GuardDuty
to detect potential threats, CloudTrail for API audit logs, and Security Hub for
unified security findings.
EOT

  default = {
    encryption  = true
    guardduty   = true
    cloudtrail  = true
    securityhub = true
  }
}

###############################################################################
# Backup Configuration
# -----------------------------------------------------------------------------
# Defines the backup retention period (in days) and optional cross-region copy,
# which is crucial for an effective disaster recovery strategy in multi-region
# deployments. The system enforces a minimum of 30 days for compliance.
###############################################################################
variable "backup_configuration" {
  type = object({
    retention_days   = number
    cross_region_copy = bool
  })

  description = <<-EOT
Specifies backup retention settings, including the mandatory retention days for
snapshots or backups, as well as cross-region copy for added resilience in case
of a primary region outage.
EOT

  default = {
    retention_days    = 30
    cross_region_copy = true
  }

  validation {
    condition     = var.backup_configuration.retention_days >= 30
    error_message = "Minimum backup retention period is 30 days"
  }
}

###############################################################################
# Monitoring and Alerting Configuration
# -----------------------------------------------------------------------------
# Allows enabling or disabling enhanced monitoring, as well as setting log
# retention periods to keep logs for investigations, compliance, and cost control.
###############################################################################
variable "monitoring_configuration" {
  type = object({
    enable_enhanced   = bool
    log_retention_days = number
  })

  description = <<-EOT
Controls enhanced monitoring and log retention for system health checks, metrics,
and alerting. Enhanced monitoring may include custom metrics, distributed tracing,
and advanced logs dashboards.
EOT

  default = {
    enable_enhanced   = true
    log_retention_days = 90
  }
}

###############################################################################
# Resource Tags
# -----------------------------------------------------------------------------
# Mandatory tags for cost allocation, ownership, and environment identification.
# Project name, environment, and business unit details help unify resource
# governance, budgets, and reporting across AWS accounts.
###############################################################################
variable "resource_tags" {
  type = map(string)

  description = <<-EOT
Mandatory key-value pairs for consistent tagging across all AWS resources to
facilitate cost allocation, auditing, and organizational compliance. Must
include at least 6 tag entries covering project, environment, ownership, etc.
EOT

  default = {
    Project           = "DogWalking"
    Environment       = null
    ManagedBy         = "Terraform"
    BusinessUnit      = "Operations"
    CostCenter        = "Platform"
    DataClassification = "Confidential"
  }

  validation {
    condition     = length(var.resource_tags) >= 6
    error_message = "All required tags must be specified"
  }
}

###############################################################################
# Compliance Controls
# -----------------------------------------------------------------------------
# Defines compliance and audit parameters, including the ability to enable
# audit logs and enforce minimum data retention to ensure we meet or exceed
# regional data protection regulations and corporate policies.
###############################################################################
variable "compliance_controls" {
  type = object({
    enable_audit_logs    = bool
    data_retention_days  = number
  })

  description = <<-EOT
Controls additional compliance-oriented settings. Includes audit logs for system
events and a mandatory minimum data retention period of 365 days to satisfy
regulatory obligations.
EOT

  default = {
    enable_audit_logs   = true
    data_retention_days = 365
  }

  validation {
    condition     = var.compliance_controls.data_retention_days >= 365
    error_message = "Minimum data retention period is 365 days for compliance"
  }
}

###############################################################################
# Exports (Optional Outputs)
# -----------------------------------------------------------------------------
# Expose key variables for referencing in other modules or external resources.
# This approach allows for multi-module dependencies to easily consume these
# global settings without redefinition.
###############################################################################
output "environment" {
  description = "The current deployment environment name (dev, staging, prod)."
  value       = var.environment
}

output "primary_region" {
  description = "Primary AWS region for the Dog Walking Platform."
  value       = var.aws_regions.primary
}

output "secondary_region" {
  description = "Secondary AWS region used for failover and disaster recovery."
  value       = var.aws_regions.secondary
}