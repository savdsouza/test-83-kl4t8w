# ---------------------------------------------------------------------------------------------
# Terraform configuration block referencing the external import "hashicorp/terraform" version ~> 1.0
# ---------------------------------------------------------------------------------------------
terraform {
  required_version = "~> 1.0" # hashicorp/terraform version ~> 1.0
}

# ---------------------------------------------------------------------------------------------
# Specifies the deployment environment (dev, staging, or prod). Validation ensures only these
# specific values are permitted. This variable is critical for environment-specific configurations.
# ---------------------------------------------------------------------------------------------
variable "environment" {
  type        = string
  description = "Deployment environment (dev/staging/prod)"

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ---------------------------------------------------------------------------------------------
# Defines the VPC ID where monitoring-related components (Prometheus, Grafana, Jaeger, ELK)
# will be deployed. Ensures isolation and security within the target AWS environment.
# ---------------------------------------------------------------------------------------------
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where monitoring infrastructure will be deployed"
}

# ---------------------------------------------------------------------------------------------
# Accepts a list of subnet IDs where monitoring components should run. Subnets must belong
# to the specified VPC and offer the necessary network routes and security group access.
# ---------------------------------------------------------------------------------------------
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for deploying monitoring components"
}

# ---------------------------------------------------------------------------------------------
# Configures the retention period for Prometheus metrics data. Uses a default of 15d
# and validates that the period is expressed in days (d), weeks (w), or years (y).
# ---------------------------------------------------------------------------------------------
variable "prometheus_retention_period" {
  type        = string
  description = "Data retention period for Prometheus metrics (e.g., 15d)"
  default     = "15d"

  validation {
    condition     = can(regex("^[0-9]+(d|w|y)$", var.prometheus_retention_period))
    error_message = "Retention period must be specified in days (d), weeks (w), or years (y)."
  }
}

# ---------------------------------------------------------------------------------------------
# Defines the admin password for the Grafana dashboard. This value is marked as sensitive
# to avoid exposing it in command outputs or logs.
# ---------------------------------------------------------------------------------------------
variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana dashboard access"
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------
# Establishes the sampling rate for Jaeger distributed tracing, expressed as a fraction
# of 1.0. Validation ensures this rate never exceeds the allowed range of 0.0 to 1.0.
# ---------------------------------------------------------------------------------------------
variable "jaeger_sampling_rate" {
  type        = number
  description = "Sampling rate for Jaeger distributed tracing (0.0 to 1.0)"
  default     = 0.1

  validation {
    condition     = var.jaeger_sampling_rate >= 0 && var.jaeger_sampling_rate <= 1
    error_message = "Sampling rate must be between 0 and 1."
  }
}

# ---------------------------------------------------------------------------------------------
# Allocates the necessary volume size for the ELK (Elasticsearch, Logstash, Kibana) stack.
# A default of 100Gi is provided, and validation enforces the notation of Mi, Gi, or Ti.
# ---------------------------------------------------------------------------------------------
variable "elk_storage_size" {
  type        = string
  description = "Storage volume size for ELK stack (e.g., 100Gi)"
  default     = "100Gi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi|Ti)$", var.elk_storage_size))
    error_message = "Storage size must be specified in Mi, Gi, or Ti."
  }
}

# ---------------------------------------------------------------------------------------------
# Accepts a map of alert notification endpoints, requiring at least one configured endpoint.
# This map can include various notification channels such as email, Slack, or PagerDuty.
# ---------------------------------------------------------------------------------------------
variable "alert_notification_endpoints" {
  type        = map(string)
  description = "Map of alert notification endpoints (e.g., email, slack, pagerduty)"

  validation {
    condition     = length(var.alert_notification_endpoints) > 0
    error_message = "At least one alert notification endpoint must be configured."
  }
}

# ---------------------------------------------------------------------------------------------
# Provides a default set of tags that will be applied to all monitoring-related infrastructure
# resources. These tags facilitate cost allocation, resource identification, and management.
# ---------------------------------------------------------------------------------------------
variable "monitoring_tags" {
  type        = map(string)
  description = "Tags to apply to all monitoring infrastructure resources"
  default = {
    ManagedBy   = "terraform"
    Component   = "monitoring"
    CostCenter  = "platform"
  }
}