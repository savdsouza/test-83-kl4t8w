###############################################################################
# Terraform Outputs for Notification Service Module
# -----------------------------------------------------------------------------
# This file exposes critical resource information needed by other modules or
# the root module, including service discovery endpoints, security group IDs,
# CloudWatch log group details, and the ECS service name/ARN for cross-service
# integration. These outputs align with security, service discovery, and
# monitoring integration requirements as detailed in the technical specification.
###############################################################################

###############################################################################
# OUTPUT: service_name
# -----------------------------------------------------------------------------
# Exposes the ECS service name for inter-service communication, registration
# within service discovery, and references in cross-module resources such as
# IAM policies or routing configurations.
###############################################################################
output "service_name" {
  description = "Name of the notification ECS service for service discovery and cross-references"
  value       = aws_ecs_service.notification.name
  sensitive   = false
}

###############################################################################
# OUTPUT: service_arn
# -----------------------------------------------------------------------------
# Exposes the ECS service ARN (in Terraform, the 'id' attribute for aws_ecs_service
# resources is the full ARN). Useful in IAM policies, resource lookups, and
# advanced integration scenarios requiring a unique service identifier.
###############################################################################
output "service_arn" {
  description = "ARN of the notification ECS service for IAM policies and service integrations"
  value       = aws_ecs_service.notification.id
  sensitive   = false
}

###############################################################################
# OUTPUT: security_group_id
# -----------------------------------------------------------------------------
# Exposes the security group ID to facilitate network security control across
# modules. Marked as sensitive to protect the group ID from inadvertent logging
# or unintended disclosure, ensuring alignment with best-practice security
# protocols and the principle of least privilege.
###############################################################################
output "security_group_id" {
  description = "ID of the security group attached to the notification service for network rules"
  value       = aws_security_group.notification.id
  sensitive   = true
}

###############################################################################
# OUTPUT: log_group_name
# -----------------------------------------------------------------------------
# Exposes the name of the CloudWatch log group associated with the notification
# service for centralized logging and monitoring. This is helpful for log
# aggregation tools, setting alarms, and ensuring consistent observability
# across environments.
###############################################################################
output "log_group_name" {
  description = "Name of the CloudWatch log group for notification service centralized logging"
  value       = local.log_group_name
  sensitive   = false
}

###############################################################################
# OUTPUT: service_discovery_arn
# -----------------------------------------------------------------------------
# Exposes the ARN of the AWS Service Discovery service if integrated with
# the notification service. This ARN is vital for service mesh functionality,
# DNS-based discovery, and advanced networking patterns that rely on dynamic
# endpoint resolution.
###############################################################################
output "service_discovery_arn" {
  description = "ARN of the service discovery entry for service mesh integration and DNS resolution"
  value       = aws_service_discovery_service.notification.arn
  sensitive   = false
}