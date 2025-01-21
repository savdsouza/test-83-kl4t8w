################################################################################
# Terraform Outputs Definition File
# This file exposes key networking resources critical to the Dog Walking
# Application infrastructure for multi-region high availability deployments.
#
# According to the technical specification, this file addresses:
#  - Network Infrastructure (Section 2.5.1 Infrastructure Requirements)
#    * Providing VPC and subnet outputs for downstream modules
#  - High Availability (Section 8.1 Deployment Environment)
#    * Ensuring outputs for distributing services across multiple AZs
#
# References:
#  - AWS Provider ~> 5.0 (see main.tf for provider configuration)
#  - Resources imported from main.tf:
#    * aws_vpc.main
#    * aws_subnet.public
#    * aws_subnet.private
################################################################################

# ------------------------------------------------------------------------------
# OUTPUT: vpc_id
# ------------------------------------------------------------------------------
# Exposes the unique ID of the primary VPC used as the main network backbone
# for the Dog Walking application. Other Terraform modules (e.g., ECS, RDS)
# will reference this ID to attach their services to the correct virtual
# private cloud.
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC used as the main network backbone for the application infrastructure"
  value       = aws_vpc.main.id
}

# ------------------------------------------------------------------------------
# OUTPUT: vpc_cidr
# ------------------------------------------------------------------------------
# Exposes the CIDR block of the primary VPC. This information is essential for
# gateway configuration, firewall rules, and other networks that may peer with
# the Dog Walking application’s VPC for secure, controlled traffic flows.
# ------------------------------------------------------------------------------
output "vpc_cidr" {
  description = "CIDR block of the VPC for network planning and security group configurations"
  value       = aws_vpc.main.cidr_block
}

# ------------------------------------------------------------------------------
# OUTPUT: public_subnet_ids
# ------------------------------------------------------------------------------
# Lists the IDs of all public subnets distributed across availability zones.
# These will typically be used for provisioning internet-facing resources such
# as load balancers or NAT gateways. By exposing them, other modules can ensure
# they place their public resources or route egress traffic correctly.
# ------------------------------------------------------------------------------
output "public_subnet_ids" {
  description = "List of public subnet IDs distributed across availability zones for load balancer placement"
  value       = [for s in aws_subnet.public : s.id]
}

# ------------------------------------------------------------------------------
# OUTPUT: private_subnet_ids
# ------------------------------------------------------------------------------
# Lists the IDs of all private subnets distributed across availability zones.
# Backend services, databases, and internal applications are generally deployed
# within these private subnets to protect them from direct internet exposure.
# ------------------------------------------------------------------------------
output "private_subnet_ids" {
  description = "List of private subnet IDs distributed across availability zones for secure service deployment"
  value       = [for s in aws_subnet.private : s.id]
}

# ------------------------------------------------------------------------------
# OUTPUT: public_subnet_cidrs
# ------------------------------------------------------------------------------
# Lists the CIDR blocks associated with each public subnet. Modules and
# submodules that need network or security group configurations (e.g.,
# restricting traffic by subnet range) can reference these CIDRs to ensure
# stricter permission sets and firewall rules.
# ------------------------------------------------------------------------------
output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks for network planning and security group rule configurations"
  value       = [for s in aws_subnet.public : s.cidr_block]
}

# ------------------------------------------------------------------------------
# OUTPUT: private_subnet_cidrs
# ------------------------------------------------------------------------------
# Lists the CIDR blocks of the private subnets, providing the necessary
# information to configure internal services, security group rules, or
# network ACLs. By exposing these CIDRs, other infrastructure components
# can maintain strict, zero-trust security boundaries where needed.
# ------------------------------------------------------------------------------
output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks for network planning and security group rule configurations"
  value       = [for s in aws_subnet.private : s.cidr_block]
}