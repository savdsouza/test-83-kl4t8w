###############################################################################
# Terraform Variables Definition File
# This file configures all network-related variables for the Dog Walking
# Application, aligning with the Technical Specification requirements:
#
# 1) Network Infrastructure (Section 2.5.1 Infrastructure Requirements)
#    - Private subnets for services
#    - Public subnets for load balancers
#    - Potential VPC peering for cross-region
#
# 2) High Availability (Section 8.1 Deployment Environment)
#    - Multi-region deployment
#    - Minimum of two Availability Zones for fault tolerance
#
# 3) Security Architecture (Section 7.3.1 Access Control)
#    - Network segmentation
#    - Secure communication between components
#
# External Dependency:
#   - Terraform ~> 1.0 for variable definitions and validations
###############################################################################

################################################################################
# Variable: vpc_cidr
# Purpose:
#   - Defines the CIDR block for the primary VPC where the Dog Walking
#     Application’s microservices and data resources will reside.
#   - This must be a valid IPv4 CIDR block to ensure proper subnetting,
#     network segmentation, and secure communication channels as per the
#     Security Architecture requirement.
################################################################################
variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.vpc_cidr))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

################################################################################
# Variable: environment
# Purpose:
#   - Indicates the deployment environment (e.g., dev, staging, prod).
#   - Restricts possible values to maintain consistent naming practices
#     and clear separation of resources across environments.
################################################################################
variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

################################################################################
# Variable: region
# Purpose:
#   - Defines the AWS region in which network resources will be deployed.
#   - Aligned with High Availability requirements (Sections 2.5.1 & 8.1)
#     supporting multi-region strategies (e.g., us-east-1, us-west-2).
################################################################################
variable "region" {
  type        = string
  description = "AWS region for network resources"

  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2"], var.region)
    error_message = "Region must be one of the supported US regions."
  }
}

################################################################################
# Variable: availability_zones
# Purpose:
#   - A list of Availability Zones for distributing workloads. 
#   - Ensures a minimum of two AZs to satisfy High Availability (Section 8.1).
################################################################################
variable "availability_zones" {
  type        = list(string)
  description = "List of AZs used to deploy resources for high availability. A minimum of two AZs is required."

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required for high availability."
  }
}

################################################################################
# Variable: public_subnet_cidrs
# Purpose:
#   - Assigns CIDR blocks for public subnets across the specified AZs, primarily
#     hosting load balancers or internet-facing services.
#   - The count must match the length of 'availability_zones' to ensure each AZ
#     has a corresponding public subnet.
################################################################################
variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets. Must match the number of availability zones."

  validation {
    condition = alltrue([
      for cidr in var.public_subnet_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ]) && length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Each public subnet CIDR must be valid, and the total must match the number of availability zones."
  }
}

################################################################################
# Variable: private_subnet_cidrs
# Purpose:
#   - Assigns CIDR blocks for private subnets across the specified AZs.
#   - Hosts backend services requiring controlled access, supporting the
#     Network Infrastructure and Security Architecture requirements.
################################################################################
variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets. Must match the number of availability zones."

  validation {
    condition = alltrue([
      for cidr in var.private_subnet_cidrs : can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ]) && length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "Each private subnet CIDR must be valid, and the total must match the number of availability zones."
  }
}

################################################################################
# Variable: enable_nat_gateway
# Purpose:
#   - Enables or disables NAT Gateway creation, allowing private subnets
#     to access the internet without exposing inbound traffic, critical for
#     secure and segmented architecture (Section 7.3.1).
################################################################################
variable "enable_nat_gateway" {
  type        = bool
  description = "Flag to enable NAT Gateway for internet access from private subnets."
  default     = true
}

################################################################################
# Variable: enable_vpn_gateway
# Purpose:
#   - Enables or disables the creation of a VPN Gateway, facilitating
#     secure site-to-site or cross-region connectivity, aligning with
#     the High Availability and Security Architecture goals.
################################################################################
variable "enable_vpn_gateway" {
  type        = bool
  description = "Flag to enable VPN Gateway for secure cross-region communication."
  default     = false
}

################################################################################
# Variable: tags
# Purpose:
#   - Tags to be applied to all network resources for identification,
#     cost reporting, and organizational purposes, ensuring consistent
#     resource labeling practices across the environment.
################################################################################
variable "tags" {
  type        = map(string)
  description = "Map of tags to apply to all network resources (e.g., project, environment)."
  default     = {}
}