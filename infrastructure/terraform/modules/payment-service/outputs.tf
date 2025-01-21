#################################################################################################
# Payment Service Outputs - PCI DSS Compliant Exports
# -----------------------------------------------------------------------------------------------
# This file exposes essential infrastructure details about the Payment Service so that other
# modules in the Dog Walking Application can consume them while maintaining strict PCI DSS
# compliance. According to the JSON specification provided, we must define five outputs that
# reference key resources from main.tf:
#
#   1) service_name             -> ECS Service Name
#   2) service_id               -> ECS Service Unique Identifier
#   3) security_group_id        -> Security Group ID
#   4) cloudwatch_log_group_name-> CloudWatch Log Group Name
#   5) task_role_arn            -> IAM Role ARN for Task Execution
#
# These outputs enable secure integration and enforce data protection requirements:
#   - The ECS service outputs allow other modules to identify and associate with the Payment
#     Service for tasks like load balancing or service discovery.
#   - The security group output ensures only permitted traffic interacts with the Payment
#     Service in compliance with PCI DSS network segmentation guidelines.
#   - The CloudWatch log group output establishes centralized logging across the infrastructure,
#     supporting audit and traceability mandates.
#   - The task role ARN output ensures that only the correct level of IAM permissions is granted
#     (principle of least privilege) to the Payment Service, safeguarding sensitive operations.
#################################################################################################

################################################################################
# OUTPUT: service_name
# ------------------------------------------------------------------------------
# Description:
#   Exports the ECS Service Name of the Payment Service. This is particularly
#   useful for integration with modules that require an explicit service name
#   (e.g., service registries, central metrics, or monitoring dashboards).
#
# Value:
#   Derived from aws_ecs_service.payment.name. The 'payment' resource name is
#   defined in main.tf, referencing the Payment microservice ECS definition.
#
# Purpose in PCI DSS Context:
#   Maintaining a clear reference to the service name ensures consistent
#   tagging and identification of the Payment Service, which is crucial for
#   compliance reporting and environment segmentation.
################################################################################
output "service_name" {
  description = "The ECS Service Name for the Payment Service, used for cross-module references."
  value       = aws_ecs_service.payment.name
}

################################################################################
# OUTPUT: service_id
# ------------------------------------------------------------------------------
# Description:
#   Exports the unique ID of the Payment ECS Service, allowing other modules to
#   programmatically reference this service for tasks such as auto-scaling,
#   service updates, or targeted configuration changes.
#
# Value:
#   Sourced from aws_ecs_service.payment.id. This ID can be distinct from
#   the user-friendly name, representing the lower-level unique identifier in
#   AWS ECS.
#
# Purpose in PCI DSS Context:
#   Facilitates direct, secure references to the Payment Service infrastructure.
#   Other Terraform modules can confirm they are attaching or modifying the
#   correct ECS service without risk of misconfiguration.
################################################################################
output "service_id" {
  description = "The unique ECS Service ID for the Payment Service."
  value       = aws_ecs_service.payment.id
}

################################################################################
# OUTPUT: security_group_id
# ------------------------------------------------------------------------------
# Description:
#   Exports the Security Group ID associated with the Payment Service tasks,
#   enabling other modules (e.g., load balancers or adjacency microservices) to
#   securely connect or apply custom ingress and egress rules while upholding
#   PCI DSS isolation requirements.
#
# Value:
#   Pulls from aws_security_group.payment_sg.id, which is defined in main.tf
#   and locked down per PCI DSS network segmentation guidelines.
#
# Purpose in PCI DSS Context:
#   Ensures that any external module needing to communicate with the Payment
#   Service does so via this Security Group, enforcing least-privilege
#   and restricted network paths to protect cardholder data environments.
################################################################################
output "security_group_id" {
  description = "Security Group ID ensuring network isolation for the Payment Service tasks."
  value       = aws_security_group.payment_sg.id
}

################################################################################
# OUTPUT: cloudwatch_log_group_name
# ------------------------------------------------------------------------------
# Description:
#   Exports the name of the CloudWatch Log Group utilized by the Payment
#   Service, allowing other operational modules or logging aggregators to
#   retrieve logs and metrics to meet auditing, monitoring, and compliance
#   demands.
#
# Value:
#   Directly references aws_cloudwatch_log_group.payment_logs.name from main.tf.
#
# Purpose in PCI DSS Context:
#   PCI DSS mandates centralized logging and audit capabilities for payment
#   operations. Providing this log group name ensures that any third-party
#   or internal module can securely retrieve logs, apply retention policies,
#   or perform intrusion detection on the Payment Service’s activity.
################################################################################
output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for Payment Service logging and auditing."
  value       = aws_cloudwatch_log_group.payment_logs.name
}

################################################################################
# OUTPUT: task_role_arn
# ------------------------------------------------------------------------------
# Description:
#   Exports the IAM Task Role ARN for the Payment Service container. This
#   reference is crucial when other components or services need to confirm
#   which role is assigned, ensuring privileged actions (like KMS decryption
#   for storing secrets or interacting with Stripe) remain restricted.
#
# Value:
#   Derived from aws_iam_role.payment_task_role.arn in main.tf, representing
#   the role implementing least privilege principles for all Payment tasks.
#
# Purpose in PCI DSS Context:
#   Strictly controls access to sensitive operations and data, aligning with
#   PCI DSS guidelines for role-based access. By exposing this ARN, only
#   the required modules can pass or interpret permissions while ensuring
#   unauthorized access is not granted.
################################################################################
output "task_role_arn" {
  description = "IAM Task Role ARN attached to the Payment Service for secure, least-privilege access."
  value       = aws_iam_role.payment_task_role.arn
}