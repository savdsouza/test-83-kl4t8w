###############################################################################
# External Import:
#   - terraform: version ~> 1.0 for core Terraform functionality in defining
#     and validating variables.
###############################################################################

###############################################################################
# VARIABLE: environment
# PURPOSE:
#   Defines the deployment environment (e.g., dev, staging, prod). Used broadly
#   in resource naming, tagging, and environment-specific configurations.
#
# VALIDATION:
#   - Must be either 'dev', 'staging', or 'prod' based on the system requirements.
###############################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

###############################################################################
# VARIABLE: project_name
# PURPOSE:
#   Identifies the project and is used for consistent naming conventions across
#   the infrastructure. Must only contain lowercase letters, numbers, and hyphens.
#
# VALIDATION:
#   - Ensures only valid characters to maintain consistency in resource naming.
###############################################################################
variable "project_name" {
  type        = string
  description = "Name of the project for resource naming"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

###############################################################################
# VARIABLE: media_retention_days
# PURPOSE:
#   Defines how many days media files will remain in standard S3 storage before
#   being transitioned to a lower-cost tier (e.g., Infrequent Access).
#
# DEFAULT:
#   - 90 days is the recommended retention period based on system requirements.
#
# VALIDATION:
#   - Must be at least 30 days to align with operational and regulatory needs.
###############################################################################
variable "media_retention_days" {
  type        = number
  description = "Number of days to retain media files in standard storage before transitioning to IA"
  default     = 90

  validation {
    condition     = var.media_retention_days >= 30
    error_message = "Media retention days must be at least 30 days."
  }
}

###############################################################################
# VARIABLE: archive_retention_days
# PURPOSE:
#   Specifies the number of days archived media remains before permanent deletion.
#   Ensures compliance with data retention policies while managing storage costs.
#
# DEFAULT:
#   - 365 days is the recommended archival retention window, allowing for
#     retrieval in case of disputes or audits.
#
# VALIDATION:
#   - Must be greater than or equal to media_retention_days to maintain logical
#     lifecycle progression from active to archived states.
###############################################################################
variable "archive_retention_days" {
  type        = number
  description = "Number of days to retain archived media files before deletion"
  default     = 365

  validation {
    condition     = var.archive_retention_days >= var.media_retention_days
    error_message = "Archive retention period must be greater than or equal to media retention period."
  }
}