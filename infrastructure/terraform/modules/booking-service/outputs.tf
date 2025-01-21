###############################################################################
# TERRAFORM OUTPUTS DEFINITION FOR THE BOOKING SERVICE MODULE
# -----------------------------------------------------------------------------
# This file exposes critical information about the Booking Service module so
# that other modules (or the root configuration) can integrate with, monitor,
# and manage this service.
#
# Requirements addressed:
# 1) Service Integration (Tech Specs 3.3.4):
#    - Exposes ECS cluster/service attributes for mesh-based routing,
#      inter-service discovery, and communication in a microservices architecture.
# 2) Infrastructure Requirements (Tech Specs 2.5.1):
#    - Outputs important infrastructure details required for monitoring,
#      high availability, and auto-scaling support across multiple AZs.
#
# Dependencies & Resources Used (from main.tf):
#   - aws_ecs_cluster.booking_service_cluster
#       * Provides the cluster's ARN and name (for service mesh integration).
#   - aws_ecs_service.booking_service
#       * Provides the ECS service name and references to the cluster for
#         service discovery, auto-scaling, and management.
#   - aws_ecs_task_definition.booking_service_task
#       * Exposes the unique ARN used to manage deployments.
#   - aws_service_discovery_service.booking_service
#       * Facilitates Cloud Map-based DNS discovery and App Mesh routing.
#
# The outputs below precisely match the JSON specification:
# - cluster_arn
# - service_name
# - task_definition_arn
# - service_url
# - service_discovery_arn
# - security_group_id
#
# All outputs use HCL output block syntax with "value" and "description".
###############################################################################

###############################################################################
# OUTPUT: cluster_arn
# -----------------------------------------------------------------------------
# Description:
#   ARN of the ECS cluster running the booking service for service mesh
#   integration. Referenced by other services to locate or mesh-route traffic
#   within the microservices environment.
###############################################################################
output "cluster_arn" {
  description = "ARN of the ECS cluster running the booking service for service mesh integration"
  value       = aws_ecs_cluster.booking_service_cluster.arn
}

###############################################################################
# OUTPUT: service_name
# -----------------------------------------------------------------------------
# Description:
#   Name of the ECS service running the booking service tasks for service
#   discovery. Useful for referencing the service in cross-module resources,
#   service discovery solutions, or higher-level orchestration triggers.
###############################################################################
output "service_name" {
  description = "Name of the ECS service running the booking service tasks for service discovery"
  value       = aws_ecs_service.booking_service.name
}

###############################################################################
# OUTPUT: task_definition_arn
# -----------------------------------------------------------------------------
# Description:
#   ARN of the task definition used by the booking service for deployment
#   management. This is required for advanced monitoring, triggering new
#   rollouts, or hooking into a CI/CD pipeline that coordinates service updates.
###############################################################################
output "task_definition_arn" {
  description = "ARN of the task definition used by the booking service for deployment management"
  value       = aws_ecs_task_definition.booking_service_task.arn
}

###############################################################################
# OUTPUT: service_url
# -----------------------------------------------------------------------------
# Description:
#   HTTPS endpoint URL for the booking service API gateway integration using the
#   format:
#       https://{service-name}.{environment}.internal
#   Other services or environment modules can reference this URL to route
#   traffic to the booking service, ensuring a standardized, environment-scoped
#   domain name.
###############################################################################
output "service_url" {
  description = "HTTPS endpoint URL for the booking service API gateway integration with format: https://{service-name}.{environment}.internal"
  value       = "https://${aws_ecs_service.booking_service.name}.${var.environment}.internal"
}

###############################################################################
# OUTPUT: service_discovery_arn
# -----------------------------------------------------------------------------
# Description:
#   ARN of the AWS Cloud Map service discovery namespace for App Mesh routing and
#   microservice discovery. Enables DNS-based lookups, direct pass-through
#   service calls, and integration with advanced routing strategies.
###############################################################################
output "service_discovery_arn" {
  description = "ARN of the AWS Cloud Map service discovery namespace for App Mesh service routing and discovery"
  value       = aws_service_discovery_service.booking_service.arn
}

###############################################################################
# OUTPUT: security_group_id
# -----------------------------------------------------------------------------
# Description:
#   ID of the security group controlling network access to the booking service
#   tasks. This is critical for applying or viewing firewall rules,
#   cross-service traffic allowances, and restricting inbound access. The value
#   uses the ECS service's network configuration to retrieve at least one
#   associated security group.
#
# NOTE:
#   If the ECS service has not been configured with an explicit security group,
#   this reference may fail. Ensure that security_groups is set in the service's
#   network_configuration or that a custom security group is assigned.
###############################################################################
output "security_group_id" {
  description = "ID of the security group controlling network access to the booking service tasks"
  value       = aws_ecs_service.booking_service.network_configuration[0].security_groups[0]
}