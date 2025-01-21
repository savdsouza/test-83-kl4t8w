###############################################################################
# VARIABLE: environment
# -----------------------------------------------------------------------------
# Purpose:
#   Defines the target environment (dev, staging, or prod) for the real-time
#   location tracking service deployment. This variable will dictate different
#   configuration settings, such as resource sizing, access rules, and
#   environment-specific parameters, aligning with best practices for
#   multi-environment infrastructures.
# Related Requirements:
#   - Aligns with environment segmentation for microservices as mentioned in
#     the technical specification under "High-Level Architecture/Core Components."
###############################################################################
variable "environment" {
  type        = string
  description = "Target environment for deployment (dev/staging/prod)."

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "The environment variable must be one of dev, staging, or prod."
  }
}

###############################################################################
# VARIABLE: aws_region
# -----------------------------------------------------------------------------
# Purpose:
#   Specifies the AWS region where all tracking-related resources will be
#   deployed, ensuring compliance with latency requirements for real-time
#   location updates. Must be consistent with the region-enabled architecture
#   supporting the Go-based service and MQTT broker.
###############################################################################
variable "aws_region" {
  type        = string
  description = "AWS region for resource deployment."
}

###############################################################################
# VARIABLE: vpc_id
# -----------------------------------------------------------------------------
# Purpose:
#   Provides the AWS VPC ID in which the tracking service and related
#   infrastructure (TimescaleDB, ECS tasks, MQTT broker, etc.) will operate.
#   Ensures proper network isolation and compliance with the system’s
#   security best practices.
###############################################################################
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where resources will be deployed."
}

###############################################################################
# VARIABLE: private_subnet_ids
# -----------------------------------------------------------------------------
# Purpose:
#   Defines the list of private subnet IDs used to host ECS tasks and
#   the MQTT broker, so that real-time tracking events are communicated
#   securely and efficiently within the private network. Critical to
#   fulfilling the real-time and geofencing requirements.
###############################################################################
variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs for resource deployment."
}

###############################################################################
# VARIABLE: ecs_task_cpu
# -----------------------------------------------------------------------------
# Purpose:
#   Allocates CPU units for each ECS task running the Go-based real-time
#   tracking service. Remember: 1 vCPU = 1024 CPU units. The default reflects
#   a balanced configuration suitable for moderate throughput in real-time
#   tracking scenarios.
# Default:
#   512 - Equates to roughly half a vCPU, providing moderate performance
#   for real-time data processing.
###############################################################################
variable "ecs_task_cpu" {
  type        = number
  description = "CPU units for ECS tasks (1 vCPU = 1024 units)."
  default     = 512
}

###############################################################################
# VARIABLE: ecs_task_memory
# -----------------------------------------------------------------------------
# Purpose:
#   Configures the memory (in MiB) to allocate for each ECS task instance
#   supporting the location tracking microservice. Properly sized memory
#   assists in stable handling of MQTT connections and geofencing logic.
# Default:
#   1024 - Sufficient for moderate concurrency in real-time use cases.
###############################################################################
variable "ecs_task_memory" {
  type        = number
  description = "Memory for ECS tasks in MiB."
  default     = 1024
}

###############################################################################
# VARIABLE: db_instance_class
# -----------------------------------------------------------------------------
# Purpose:
#   Specifies the instance class for the TimescaleDB (hosted on PostgreSQL)
#   database that stores location and walk tracking data. Must be capable
#   of handling high write throughput and time-series queries.
# Default:
#   "db.t3.medium" - A cost-effective instance class balanced for I/O and CPU
#   performance to support real-time location write operations.
###############################################################################
variable "db_instance_class" {
  type        = string
  description = "Instance class for TimescaleDB."
  default     = "db.t3.medium"
}

###############################################################################
# VARIABLE: db_allocated_storage
# -----------------------------------------------------------------------------
# Purpose:
#   Configures the allocated storage (in GB) for the TimescaleDB instance, used
#   to contain massive volumes of GPS data and walk timelines. Must be sized
#   based on projected usage and the system’s data retention policies.
# Default:
#   20 - A moderate initial allocation for pilot or early-stage deployments.
###############################################################################
variable "db_allocated_storage" {
  type        = number
  description = "Allocated storage for TimescaleDB in GB."
  default     = 20
}

###############################################################################
# VARIABLE: enable_multi_az
# -----------------------------------------------------------------------------
# Purpose:
#   Flag to indicate whether Multi-AZ support should be enabled on the database
#   layer. Critical for HA (High Availability) in the real-time tracking domain,
#   ensuring minimal downtime during maintenance or outages.
# Default:
#   false - Disabled by default, but can be set to true to satisfy stringent
#   SLA requirements for production.
###############################################################################
variable "enable_multi_az" {
  type        = bool
  description = "Enable Multi-AZ deployment for high availability."
  default     = false
}

###############################################################################
# VARIABLE: mqtt_broker_instance_type
# -----------------------------------------------------------------------------
# Purpose:
#   Defines the instance type used for the MQTT broker. The broker
#   underpins real-time messaging for location updates. Must be sized to
#   handle concurrent connections from dog walkers and owners tracking sessions.
# Default:
#   "t3.micro" - Minimal resource usage; suitable for lower-volume or dev
#   environments. Adjust upward for higher concurrency needs.
###############################################################################
variable "mqtt_broker_instance_type" {
  type        = string
  description = "Instance type for MQTT broker."
  default     = "t3.micro"
}

###############################################################################
# VARIABLE: tags
# -----------------------------------------------------------------------------
# Purpose:
#   Allows the assignment of key-value tags to resources created in this
#   module, providing cost tracking and organizational clarity. E.g.,
#   "Environment" : "production", "Application" : "dog-walking-tracker".
# Default:
#   Empty map - No tags by default. Should be overridden by caller modules
#   or at the workspace level.
###############################################################################
variable "tags" {
  type        = map(string)
  description = "Resource tags for cost tracking and organization."
  default     = {}
}