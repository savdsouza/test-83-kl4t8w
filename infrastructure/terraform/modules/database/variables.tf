###############################################################################
# Terraform Variables Definition File
# ----------------------------------------------------------------------------- 
# This file defines all input variables for the Database Module supporting
# PostgreSQL (Auth), MongoDB (Booking), and TimescaleDB (Tracking) deployments,
# in alignment with the technical specifications:
#
#  - Data Storage Components (Section 2.2.2):
#    * PostgreSQL for user/auth data
#    * MongoDB for booking records
#    * TimescaleDB for time-series location tracking
#
#  - High Availability Architecture (Section 8.2.2):
#    * Multi-region configurations
#    * Automated failover and replication
#
#  - Data Security (Section 7.2) / Data Classification and Encryption:
#    * At-rest encryption, KMS key rotation
#    * Secure backups and retention settings
#
# Additionally, these variables support advanced configurations to ensure
# enterprise readiness, including cross-region replicas, multi-AZ deployment,
# performance insights, and enhanced monitoring.
#
# External Provider Reference:
#   - hashicorp/aws ~> 5.0
###############################################################################


###############################################################################
# VARIABLE: environment
# ----------------------------------------------------------------------------- 
# Description:
#   Specifies the deployment environment for the databases. Valid options are
#   "development", "staging", or "production". This variable helps partition
#   resources logically and can be used in naming or tagging to differentiate
#   multiple environments.
#
# Validation:
#   - Must match the regex pattern for environment naming.
###############################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (development/staging/production)"

  validation {
    condition     = can(regex("^(development|staging|production)$", var.environment))
    error_message = "Environment must be development, staging, or production"
  }
}


###############################################################################
# VARIABLE: region
# ----------------------------------------------------------------------------- 
# Description:
#   Defines the primary AWS region for deploying the database resources. 
#   This plays a key role in achieving low-latency connections for local
#   user bases and ensures alignment with compliance or data residency
#   requirements.
#
# Default:
#   us-east-1
###############################################################################
variable "region" {
  type        = string
  description = "Primary AWS region for database deployment"
  default     = "us-east-1"
}


###############################################################################
# VARIABLE: secondary_region
# ----------------------------------------------------------------------------- 
# Description:
#   Defines the secondary AWS region for cross-region replication. By specifying
#   a secondary region, you can configure automated failover and replication
#   strategies for high availability and disaster recovery in line with
#   multi-region architecture.
#
# Default:
#   us-west-2
###############################################################################
variable "secondary_region" {
  type        = string
  description = "Secondary AWS region for cross-region replication"
  default     = "us-west-2"
}


###############################################################################
#                             POSTGRESQL VARIABLES
# ----------------------------------------------------------------------------- 
# The following variables configure Amazon RDS for PostgreSQL, used by the
# Auth service to store user credentials, profile data, and other relational
# records. These settings enforce performance, high availability, and data
# security as defined in the technical specs (Sections 2.2.2 & 7.2).
###############################################################################


###############################################################################
# VARIABLE: postgres_instance_class
# ----------------------------------------------------------------------------- 
# Description:
#   The instance class for the PostgreSQL RDS cluster. Typically specified as
#   `db.<instance family>.<size>` (e.g., db.r6g.xlarge). Sizing depends on
#   operational load, read/write traffic, and query complexity.
#
# Default:
#   db.r6g.xlarge
###############################################################################
variable "postgres_instance_class" {
  type        = string
  description = "Instance class for PostgreSQL RDS instances"
  default     = "db.r6g.xlarge"
}


###############################################################################
# VARIABLE: postgres_allocated_storage
# ----------------------------------------------------------------------------- 
# Description:
#   The allocated storage (in GB) assigned to the PostgreSQL RDS. This influences
#   the baseline IOPS, storage costs, and overall capacity for relational data
#   from the Auth service. Must be at least 100GB to handle production workloads
#   effectively.
#
# Default:
#   100
#
# Validation:
#   - Must be >= 100
###############################################################################
variable "postgres_allocated_storage" {
  type        = number
  description = "Allocated storage in GB for PostgreSQL RDS"
  default     = 100

  validation {
    condition     = var.postgres_allocated_storage >= 100
    error_message = "PostgreSQL storage must be at least 100GB"
  }
}


###############################################################################
# VARIABLE: postgres_backup_retention_period
# ----------------------------------------------------------------------------- 
# Description:
#   The number of days to retain automatic backups for the PostgreSQL database.
#   Ensures data recovery objectives and regulatory compliance are met. Must be
#   at least 7.
#
# Default:
#   30
#
# Validation:
#   - Must be >= 7
###############################################################################
variable "postgres_backup_retention_period" {
  type        = number
  description = "Number of days to retain PostgreSQL backups"
  default     = 30

  validation {
    condition     = var.postgres_backup_retention_period >= 7
    error_message = "Backup retention must be at least 7 days"
  }
}


###############################################################################
# VARIABLE: postgres_multi_az
# ----------------------------------------------------------------------------- 
# Description:
#   Enables Multi-AZ deployment for PostgreSQL, providing enhanced availability
#   and automatic failover support. When set to true, a synchronous standby
#   replica is launched in a different Availability Zone.
#
# Default:
#   true
###############################################################################
variable "postgres_multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment for PostgreSQL"
  default     = true
}


###############################################################################
# VARIABLE: postgres_cross_region_replica
# ----------------------------------------------------------------------------- 
# Description:
#   When enabled, creates a cross-region replica for PostgreSQL in the specified
#   secondary region. This supports multi-region resiliency, fulfilling the High
#   Availability Architecture (Section 8.2.2) for failover protection.
#
# Default:
#   true
###############################################################################
variable "postgres_cross_region_replica" {
  type        = bool
  description = "Enable cross-region read replica for PostgreSQL"
  default     = true
}


###############################################################################
#                               MONGODB VARIABLES
# ----------------------------------------------------------------------------- 
# These variables configure MongoDB (e.g., Amazon DocumentDB or a self-managed
# cluster) for booking data. They ensure high availability via replica sets,
# define necessary storage parameters, and maintain data backups for compliance
# as specified in the technical specs (Sections 2.2.2 & 7.2).
###############################################################################


###############################################################################
# VARIABLE: mongodb_instance_type
# ----------------------------------------------------------------------------- 
# Description:
#   Specifies the instance type for MongoDB clusters, typically in the format
#   `db.<instance family>.<size>` (e.g., db.r6g.xlarge). Balances cost with
#   performance demands for booking data operations.
#
# Default:
#   db.r6g.xlarge
###############################################################################
variable "mongodb_instance_type" {
  type        = string
  description = "Instance type for MongoDB DocumentDB clusters"
  default     = "db.r6g.xlarge"
}


###############################################################################
# VARIABLE: mongodb_replica_count
# ----------------------------------------------------------------------------- 
# Description:
#   Number of replica set members for MongoDB. A minimum of 3 is mandatory for
#   high availability and to maintain a quorum for the booking service logs and
#   data distribution. 
#
# Default:
#   3
#
# Validation:
#   - Must be >= 3
###############################################################################
variable "mongodb_replica_count" {
  type        = number
  description = "Number of MongoDB replica set members"
  default     = 3

  validation {
    condition     = var.mongodb_replica_count >= 3
    error_message = "MongoDB must have at least 3 replicas for high availability"
  }
}


###############################################################################
# VARIABLE: mongodb_backup_retention_period
# ----------------------------------------------------------------------------- 
# Description:
#   The number of days to retain MongoDB backups, ensuring sufficient coverage
#   for restoration in the event of data corruption or operational failures.
#
# Default:
#   30
###############################################################################
variable "mongodb_backup_retention_period" {
  type        = number
  description = "Number of days to retain MongoDB backups"
  default     = 30
}


###############################################################################
# VARIABLE: mongodb_sharding_enabled
# ----------------------------------------------------------------------------- 
# Description:
#   Sharding splits data across multiple nodes to handle large volumes and
#   high ingestion rates. If true, the module configures or enables sharding
#   for improved scalability in the booking service.
#
# Default:
#   true
###############################################################################
variable "mongodb_sharding_enabled" {
  type        = bool
  description = "Enable sharding for MongoDB clusters"
  default     = true
}


###############################################################################
#                           TIMESCALEDB VARIABLES
# ----------------------------------------------------------------------------- 
# TimescaleDB extends PostgreSQL for time-series data, essential for storing
# and analyzing GPS tracking details in real-time. These variables specify 
# resource sizing, storage capacity, and backups to maintain operational
# continuity (Sections 2.2.2 & 7.2).
###############################################################################


###############################################################################
# VARIABLE: timescaledb_instance_class
# ----------------------------------------------------------------------------- 
# Description:
#   Instance class for the TimescaleDB RDS instance. This instance type should
#   be sized for handling high write throughput and complex time-series queries
#   for real-time tracking analytics.
#
# Default:
#   db.r6g.2xlarge
###############################################################################
variable "timescaledb_instance_class" {
  type        = string
  description = "Instance class for TimescaleDB RDS instances"
  default     = "db.r6g.2xlarge"
}


###############################################################################
# VARIABLE: timescaledb_storage_size
# ----------------------------------------------------------------------------- 
# Description:
#   Allocated storage (in GB) for the TimescaleDB RDS instance. High ingestion 
#   rates from location data require substantial storage. Must be at least 500GB
#   to accommodate large time-series data sets.
#
# Default:
#   500
#
# Validation:
#   - Must be >= 500
###############################################################################
variable "timescaledb_storage_size" {
  type        = number
  description = "Allocated storage in GB for TimescaleDB"
  default     = 500

  validation {
    condition     = var.timescaledb_storage_size >= 500
    error_message = "TimescaleDB storage must be at least 500GB"
  }
}


###############################################################################
# VARIABLE: timescaledb_backup_retention_period
# ----------------------------------------------------------------------------- 
# Description:
#   Retention duration (in days) for TimescaleDB backups. This ensures historical
#   location data can be recovered in case of unexpected deletions or corruption.
#
# Default:
#   30
###############################################################################
variable "timescaledb_backup_retention_period" {
  type        = number
  description = "Number of days to retain TimescaleDB backups"
  default     = 30
}


###############################################################################
#                      ENCRYPTION AND KMS CONFIGURATION
# ----------------------------------------------------------------------------- 
# These variables enable at-rest encryption for all databases and control the
# automatic rotation of KMS keys. This upholds data security requirements
# (Section 7.2) by safeguarding sensitive personal, financial, and location data.
###############################################################################


###############################################################################
# VARIABLE: enable_encryption
# ----------------------------------------------------------------------------- 
# Description:
#   Master switch to enable or disable encryption at rest for all database
#   resources. When enabled, all data is encrypted using AWS KMS to ensure
#   compliance with regulatory standards and internal policies.
#
# Default:
#   true
###############################################################################
variable "enable_encryption" {
  type        = bool
  description = "Enable at-rest encryption for all databases"
  default     = true
}


###############################################################################
# VARIABLE: kms_key_rotation_enabled
# ----------------------------------------------------------------------------- 
# Description:
#   Toggles automatic KMS key rotation for encryption keys protecting database
#   instances. This rotation practice helps reduce long-term exposure by
#   regularly cycling cryptographic keys as part of best security practices.
#
# Default:
#   true
###############################################################################
variable "kms_key_rotation_enabled" {
  type        = bool
  description = "Enable automatic rotation of KMS keys"
  default     = true
}


###############################################################################
#             PERFORMANCE INSIGHTS & ENHANCED MONITORING
# ----------------------------------------------------------------------------- 
# These variables enable advanced monitoring and performance insights for
# the RDS engines. They provide deeper visibility into query performance
# and resource usage, assisting with capacity planning and troubleshooting
# (Section 2.4 Cross-Cutting Concerns).
###############################################################################


###############################################################################
# VARIABLE: enable_performance_insights
# ----------------------------------------------------------------------------- 
# Description:
#   Activates AWS Performance Insights for real-time metrics on database load,
#   wait times, and user sessions. Helps identify performance bottlenecks and
#   tune queries.
#
# Default:
#   true
###############################################################################
variable "enable_performance_insights" {
  type        = bool
  description = "Enable Performance Insights for RDS instances"
  default     = true
}


###############################################################################
# VARIABLE: enable_enhanced_monitoring
# ----------------------------------------------------------------------------- 
# Description:
#   Enables Enhanced Monitoring, which collects metrics directly from the DB
#   instance and streams them to CloudWatch with more granular detail than
#   standard RDS metrics, aiding in advanced operational observability.
#
# Default:
#   true
###############################################################################
variable "enable_enhanced_monitoring" {
  type        = bool
  description = "Enable Enhanced Monitoring for detailed metrics"
  default     = true
}


###############################################################################
# VARIABLE: monitoring_interval
# ----------------------------------------------------------------------------- 
# Description:
#   Configures the frequency (in seconds) at which Enhanced Monitoring metrics
#   are gathered. Acceptable values include [0, 1, 5, 10, 15, 30, 60]. If set
#   to 0, Enhanced Monitoring is disabled for the instance.
#
# Default:
#   15
#
# Validation:
#   - Must be one of 0, 1, 5, 10, 15, 30, 60
###############################################################################
variable "monitoring_interval" {
  type        = number
  description = "Enhanced Monitoring interval in seconds"
  default     = 15

  validation {
    condition     = contains([0, 1, 5, 10, 15, 30, 60], var.monitoring_interval)
    error_message = "Monitoring interval must be 0, 1, 5, 10, 15, 30, or 60 seconds"
  }
}


###############################################################################
#                 SUBNET, BACKUP, AND MAINTENANCE SETTINGS
# ----------------------------------------------------------------------------- 
# The following variables define core infrastructure placement details,
# as well as time windows for backups and general maintenance. They ensure
# alignment with operational requirements (Section 2.5.1 & 7.2).
###############################################################################


###############################################################################
# VARIABLE: subnet_ids
# ----------------------------------------------------------------------------- 
# Description:
#   A list of subnet IDs in which the database resources will be deployed. 
#   Typically references private subnets for secure, internal-only access,
#   consistent with best-practice security architecture.
###############################################################################
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for database deployment"
}


###############################################################################
# VARIABLE: backup_window
# ----------------------------------------------------------------------------- 
# Description:
#   Specifies the preferred daily time range (UTC) for automated backups.
#   Should be a period of low database traffic and minimal operational
#   impact. Format is hh24:mi-hh24:mi.
#
# Default:
#   03:00-04:00
###############################################################################
variable "backup_window" {
  type        = string
  description = "Preferred backup window"
  default     = "03:00-04:00"
}


###############################################################################
# VARIABLE: maintenance_window
# ----------------------------------------------------------------------------- 
# Description:
#   Defines the weekly time range (UTC) for system maintenance, such as OS and
#   database patching. The format is Ddd:hh24:mi-Ddd:hh24:mi (e.g.,
#   Mon:05:00-Mon:06:00). This ensures minimal disruption by scheduling
#   maintenance outside peak hours.
#
# Default:
#   Mon:04:00-Mon:05:00
###############################################################################
variable "maintenance_window" {
  type        = string
  description = "Preferred maintenance window"
  default     = "Mon:04:00-Mon:05:00"
}


###############################################################################
# VARIABLE: deletion_protection
# ----------------------------------------------------------------------------- 
# Description:
#   Prevents accidental deletion of database instances in a production setting.
#   When set to true, requests to delete the database may fail unless this
#   flag is explicitly disabled first.
#
# Default:
#   true
###############################################################################
variable "deletion_protection" {
  type        = bool
  description = "Enable deletion protection for databases"
  default     = true
}