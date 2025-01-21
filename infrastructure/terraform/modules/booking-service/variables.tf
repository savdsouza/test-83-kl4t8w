###############################################################################
# Terraform Variables Definition File for the Booking Service Module
# -----------------------------------------------------------------------------
# This file configures all required inputs to provision the Java/Spring-based
# booking service infrastructure. It supports high availability features,
# multi-AZ deployments, auto-scaling, service mesh integration, and references
# an imported MongoDB connection string variable from the database module.
#
# Requirements Addressed:
#  1) Booking Service Infrastructure
#     - Container-based service configuration
#     - Java/Spring environment-specific deployment parameters
#  2) High Availability
#     - Subnet selection for multi-AZ
#     - Auto-scaling limits
#  3) Service Integration
#     - Enable AWS App Mesh for inter-service communication
#     - Infrastructure ready for microservices patterns
#
# Global Conventions:
#  - All variables declared with extensive comments and validation (where appropriate).
#  - All variables follow an enterprise-grade naming structure with robust descriptions.
###############################################################################


###############################################################################
# VARIABLE: environment
# -----------------------------------------------------------------------------
# Description:
#   Specifies the deployment environment for the Booking Service module. Must
#   be one of: dev, staging, or prod, ensuring consistent resource naming and
#   separation of environments in line with best practices.
###############################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (dev/staging/prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod"
  }
}


###############################################################################
# VARIABLE: vpc_id
# -----------------------------------------------------------------------------
# Description:
#   The ID of the VPC in which the booking service resources will be created.
#   This integrates with networking modules to ensure alignment with multi-AZ
#   and network segmentation constraints.
###############################################################################
variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the booking service will be deployed"
}


###############################################################################
# VARIABLE: subnet_ids
# -----------------------------------------------------------------------------
# Description:
#   A list of subnet IDs (likely private subnets) enabling multi-AZ deployments
#   for high availability. Each subnet should reside in a unique Availability
#   Zone to satisfy fault tolerance requirements.
###############################################################################
variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for multi-AZ deployment of the booking service"
}


###############################################################################
# VARIABLE: service_name
# -----------------------------------------------------------------------------
# Description:
#   Logical name for the booking service. Used for naming container resources,
#   ECS services, or other references throughout the infrastructure.
#
# Default:
#   "booking-service"
###############################################################################
variable "service_name" {
  type        = string
  description = "Name of the booking service"
  default     = "booking-service"
}


###############################################################################
# VARIABLE: container_image
# -----------------------------------------------------------------------------
# Description:
#   Docker image URI for the Java/Spring booking service container. This image
#   must be stored either in a container registry such as ECR or Docker Hub.
###############################################################################
variable "container_image" {
  type        = string
  description = "Docker image for the Java/Spring booking service container"
}


###############################################################################
# VARIABLE: container_port
# -----------------------------------------------------------------------------
# Description:
#   The TCP port exposed by the booking service container. Commonly 8080 for a
#   Spring Boot application, but can be overridden if needed.
#
# Default:
#   8080
###############################################################################
variable "container_port" {
  type        = number
  description = "Port exposed by the booking service container"
  default     = 8080

  validation {
    condition     = var.container_port > 0 && var.container_port < 65536
    error_message = "Container port must be a valid TCP port between 1 and 65535."
  }
}


###############################################################################
# VARIABLE: desired_count
# -----------------------------------------------------------------------------
# Description:
#   The desired number of booking service tasks during normal operation. This
#   helps define baseline capacity for the ECS/fargate tasks. Must be a positive
#   integer.
#
# Default:
#   2
###############################################################################
variable "desired_count" {
  type        = number
  description = "Desired number of booking service tasks for normal operation"
  default     = 2

  validation {
    condition     = var.desired_count >= 1
    error_message = "The desired_count must be at least 1."
  }
}


###############################################################################
# VARIABLE: max_capacity
# -----------------------------------------------------------------------------
# Description:
#   Upper bound on the number of tasks allowed by auto-scaling. Must be at least
#   as large as desired_count to support scale-out events.
#
# Default:
#   10
###############################################################################
variable "max_capacity" {
  type        = number
  description = "Maximum number of booking service tasks for auto-scaling"
  default     = 10

  validation {
    condition     = var.max_capacity >= var.desired_count
    error_message = "max_capacity must be greater than or equal to desired_count."
  }
}


###############################################################################
# VARIABLE: cpu
# -----------------------------------------------------------------------------
# Description:
#   CPU allocation for the booking service in ECS (1 vCPU = 1024). Must be a
#   positive multiple of 256. This setting influences how the container is
#   scheduled within a task.
#
# Default:
#   1024
###############################################################################
variable "cpu" {
  type        = number
  description = "CPU units for the booking service task (1 vCPU = 1024)"
  default     = 1024

  validation {
    condition     = (var.cpu % 256) == 0 && var.cpu > 0
    error_message = "CPU must be a positive multiple of 256 (e.g., 256, 512, 1024...)."
  }
}


###############################################################################
# VARIABLE: memory
# -----------------------------------------------------------------------------
# Description:
#   Memory allocation (in MiB) for the booking service container. Must be
#   sufficient for Java-based workloads and must be a positive integer.
#
# Default:
#   2048
###############################################################################
variable "memory" {
  type        = number
  description = "Memory (in MiB) for the booking service task"
  default     = 2048

  validation {
    condition     = var.memory > 0
    error_message = "Memory must be a positive value in MiB."
  }
}


###############################################################################
# VARIABLE: health_check_path
# -----------------------------------------------------------------------------
# Description:
#   Specifies the HTTP path for a Spring Boot Actuator health check endpoint
#   used by load balancers or container orchestrators to confirm the service
#   is healthy.
#
# Default:
#   "/actuator/health"
###############################################################################
variable "health_check_path" {
  type        = string
  description = "Spring Boot Actuator health check endpoint for the booking service"
  default     = "/actuator/health"

  validation {
    condition     = can(regex("^/.*", var.health_check_path))
    error_message = "Health check path must begin with a forward slash."
  }
}


###############################################################################
# VARIABLE: enable_service_mesh
# -----------------------------------------------------------------------------
# Description:
#   Boolean controlling whether AWS App Mesh or an equivalent service mesh is
#   enabled for the booking service. Enabling this integrates sidecars or Envoy
#   proxies to handle inter-service traffic, facilitating advanced routing and
#   observability.
#
# Default:
#   true
###############################################################################
variable "enable_service_mesh" {
  type        = bool
  description = "Enable AWS App Mesh integration for service-to-service communication"
  default     = true
}


###############################################################################
# VARIABLE: tags
# -----------------------------------------------------------------------------
# Description:
#   A map of arbitrary tags to assign to all booking service infrastructure
#   resources for cost allocation, environment structuring, or general metadata.
###############################################################################
variable "tags" {
  type        = map(string)
  description = "Resource tags for the booking service infrastructure"
  default     = {}
}


###############################################################################
# VARIABLE: mongodb_connection_string
# -----------------------------------------------------------------------------
# Description:
#   Connection string imported from the database module for MongoDB. This
#   variable enables the booking service to store and query booking records
#   within the specified MongoDB cluster.
#
# Note:
#   Conforms to the import referencing: 'mongodb_connection_string' from the
#   database module. Typically set by an external module output or root module
#   assignment.
###############################################################################
variable "mongodb_connection_string" {
  type        = string
  description = "Connection string for the MongoDB instance used by the booking service"

  validation {
    condition     = length(var.mongodb_connection_string) > 0
    error_message = "mongodb_connection_string cannot be empty."
  }
}