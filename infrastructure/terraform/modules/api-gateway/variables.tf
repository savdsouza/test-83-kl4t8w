###############################################################################
# External Import: AWS provider (hashicorp/aws ~> 5.0)
# This variables file defines all configuration parameters required
# for setting up the API Gateway module. It includes security controls,
# monitoring features, throttling, caching, and other production-grade
# configuration knobs that align with the Dog Walking Application’s
# technical requirements.
###############################################################################

###############################################################################
# Name of the API Gateway instance for the Dog Walking application.
# Must be between 3 and 64 characters in length and contain only
# alphanumeric characters and hyphens.
###############################################################################
variable "api_name" {
  description = "Name of the API Gateway instance for the Dog Walking application"
  type        = string
  default     = "dog-walking-api"

  validation {
    condition     = length(var.api_name) > 3 && length(var.api_name) <= 64 && can(regex("^[a-zA-Z0-9-]+$", var.api_name))
    error_message = "API name must be between 3 and 64 characters and contain only alphanumeric characters and hyphens"
  }
}

###############################################################################
# Deployment environment used to differentiate security and scaling settings,
# as well as overall naming conventions. Acceptable values are dev, staging, or prod.
###############################################################################
variable "environment" {
  description = "Deployment environment (dev/staging/prod) affecting security and scaling configurations"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod"
  }
}

###############################################################################
# Determines the API Gateway endpoint type. Can be REGIONAL, PRIVATE, or EDGE.
# Defaults to REGIONAL for improved latency within a selected region.
###############################################################################
variable "endpoint_type" {
  description = "API Gateway endpoint type determining network access pattern"
  type        = string
  default     = "REGIONAL"

  validation {
    condition     = can(regex("^(REGIONAL|PRIVATE|EDGE)$", var.endpoint_type))
    error_message = "Endpoint type must be REGIONAL, PRIVATE, or EDGE"
  }
}

###############################################################################
# Enables AWS X-Ray tracing for request and performance monitoring to provide
# insights into request behavior, dependencies, and performance bottlenecks.
###############################################################################
variable "enable_xray" {
  description = "Enable AWS X-Ray tracing for request tracking and performance monitoring"
  type        = bool
  default     = true
}

###############################################################################
# Enables AWS Web Application Firewall (WAF) to help protect APIs from common
# exploits and security vulnerabilities.
###############################################################################
variable "enable_waf" {
  description = "Enable AWS WAF protection with custom rule sets for API security"
  type        = bool
  default     = true
}

###############################################################################
# Defines the steady-state rate limit (requests per second) at the account level
# for API Gateway. Must be between 50 and 500.
###############################################################################
variable "throttling_rate_limit" {
  description = "API Gateway account level throttling rate limit per second"
  type        = number
  default     = 100

  validation {
    condition     = var.throttling_rate_limit >= 50 && var.throttling_rate_limit <= 500
    error_message = "Rate limit must be between 50 and 500 requests per second"
  }
}

###############################################################################
# Defines the burst limit for handling request spikes at the API Gateway level.
# Must be between 100 and 1000.
###############################################################################
variable "throttling_burst_limit" {
  description = "API Gateway account level throttling burst limit for request spikes"
  type        = number
  default     = 200

  validation {
    condition     = var.throttling_burst_limit >= 100 && var.throttling_burst_limit <= 1000
    error_message = "Burst limit must be between 100 and 1000 requests"
  }
}

###############################################################################
# Specifies the number of days for retaining API Gateway logs in CloudWatch.
# Must be one of the allowed retention periods: 1, 3, 5, 7, 14, 30, 60, 90,
# 120, 150, 180, 365, 400, 545, 731, 1827, or 3653.
###############################################################################
variable "log_retention_days" {
  description = "Number of days to retain API Gateway logs for compliance and debugging"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be one of the allowed CloudWatch values"
  }
}

###############################################################################
# Enables API Gateway caching to improve performance and reduce load on backend
# services. This is typically activated in production to serve responses faster.
###############################################################################
variable "enable_caching" {
  description = "Enable API Gateway caching to improve response times and reduce backend load"
  type        = bool
  default     = true
}

###############################################################################
# Defines the size of API Gateway cache in GB. Acceptable values are limited
# to 0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118.0, or 237.0.
###############################################################################
variable "cache_size" {
  description = "Size of API Gateway cache in GB, affecting performance and cost"
  type        = number
  default     = 0.5

  validation {
    condition     = contains([0.5, 1.6, 6.1, 13.5, 28.4, 58.2, 118.0, 237.0], var.cache_size)
    error_message = "Cache size must be one of the allowed values in GB"
  }
}

###############################################################################
# Enables detailed access logging for the API Gateway, which is critical
# for security audits, troubleshooting, and compliance requirements.
###############################################################################
variable "enable_access_logs" {
  description = "Enable detailed access logging for security and audit purposes"
  type        = bool
  default     = true
}

###############################################################################
# Specifies the SSL policy for client connections. The default is TLS_1_2
# for modern security. Optionally, TLS_1_0 can be used for legacy support
# but is discouraged in production environments.
###############################################################################
variable "ssl_policy" {
  description = "SSL policy for API Gateway client connections"
  type        = string
  default     = "TLS_1_2"

  validation {
    condition     = can(regex("^TLS_1_2$|^TLS_1_0$", var.ssl_policy))
    error_message = "SSL policy must be TLS_1_2 or TLS_1_0"
  }
}

###############################################################################
# Map of user-defined tags to assist with cost allocation, environment tracking,
# and resource identification across AWS services.
###############################################################################
variable "tags" {
  description = "Additional tags for API Gateway resources including cost allocation and environment tracking"
  type        = map(string)
  default     = {}
}

###############################################################################
# Outputs: Export key variables to allow referencing within external
# module integrations, environment-specific naming constructs, or
# cross-module linking.
###############################################################################

output "api_name" {
  description = "Exports the API name for use in main.tf and other module configurations"
  value       = var.api_name
}

output "environment" {
  description = "Exports the environment for resource naming and environment-specific configurations"
  value       = var.environment
}