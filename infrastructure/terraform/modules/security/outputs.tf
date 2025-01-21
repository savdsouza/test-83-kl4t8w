################################################################################
# FILE: outputs.tf
# ------------------------------------------------------------------------------
# This Terraform file defines all output variables required by the Security
# Module for the Dog Walking Mobile Application project. The outputs include:
#   • WAF Web ACL ARN for protection against common web exploits and DDoS
#   • Security Group IDs used for network isolation across various components
#   • KMS Key ARN for encryption of sensitive data at rest
#   • IAM Role ARNs for implementing role-based access control
#
# These outputs directly address the following requirements from the technical
# specification:
#   1) Security Architecture (Section 2.4.2) – allows external modules to
#      retrieve references to WAF, security groups, and IAM roles for secure
#      boundary protections.
#   2) Data Security (Section 7.2) – exports the KMS Key ARN, ensuring that any
#      resource needing encryption can leverage this key.
#   3) Access Control (Section 7.3.1) – provides necessary IAM role ARNs and
#      security group configurations to enforce least privilege and network
#      segmentation.
#
# Internal Imports Referenced:
#   - aws_wafv2_web_acl.main:   Provides the ARN for the Web ACL resource
#   - aws_security_group.*:     Security group resource IDs used for isolating
#                               application, services, and database layers
#   - aws_kms_key.main:         Encryption key ARN for data protection
#   - aws_iam_role.*:           IAM roles ensuring correct privileges
################################################################################

###############################################################################
# Output: waf_web_acl_arn
# -----------------------------------------------------------------------------
# Description:
#   Exports the ARN of the WAF web ACL attached to protect API Gateway (and
#   potentially other endpoints) from common web vectors, such as SQL injection,
#   XSS, and DDoS-based attacks. This output is essential for modules or
#   configurations that need to associate resources with the existing WAF.
#
# Value:
#   Either the WAF ACL ARN (if present) or null if WAF is disabled, referencing
#   the resource "aws_wafv2_web_acl.main" in main.tf.
#
# Purpose in Requirements:
#   • Requirement: “Enable WAF protection for API Gateway”
#   • Technical Specifications/2.4.2 Security Architecture:
#     Ensures the exported ARN ties to the security boundary.
###############################################################################
output "waf_web_acl_arn" {
  type        = string
  description = "ARN of the WAF web ACL used for protecting API Gateway endpoints from common web exploits and DDoS attacks"

  # Reflecting the use of a count in main.tf, we safely reference index [0].
  value = length(aws_wafv2_web_acl.main) > 0 ? aws_wafv2_web_acl.main[0].arn : null
}

###############################################################################
# Output: security_group_ids
# -----------------------------------------------------------------------------
# Description:
#   Exports a map of Security Group IDs, enabling other modules or resources to
#   consume these SGs for network-level isolation. The map differentiates SGs
#   for the API Gateway, application services, and database layers.
#
# Value:
#   A structure referencing:
#     • aws_security_group.api_gateway_sg.id
#     • aws_security_group.services_sg.id
#     • aws_security_group.database_sg.id
#   Each tied to specialized security groups in main.tf (or potentially in
#   complementary configuration files).
#
# Purpose in Requirements:
#   • Requirement: “Implement network segmentation”
#   • Technical Specifications/7.2 Data Security & 7.3.1 Access Control:
#     Ensures encryption in transit and isolation from unauthorized traffic.
###############################################################################
output "security_group_ids" {
  type        = map(string)
  description = "Map of security group IDs for network isolation between different application components including API Gateway, services, and databases"

  value = {
    api_gateway = aws_security_group.api_gateway_sg.id
    services    = aws_security_group.services_sg.id
    database    = aws_security_group.database_sg.id
  }
}

###############################################################################
# Output: kms_key_arn
# -----------------------------------------------------------------------------
# Description:
#   Exports the ARN of the AWS KMS Key used to encrypt sensitive data at rest,
#   including personal user details, payment info, and internal secrets. The
#   encryption key must align with the project’s data-protection policies.
#
# Value:
#   The ARN from aws_kms_key.main in main.tf, representing the primary encryption
#   key leveraged across the system architecture.
#
# Sensitive:
#   Marked true to ensure Terraform handles the key output securely without
#   unintentional logging or exposure.
#
# Purpose in Requirements:
#   • Requirement: “Enable data encryption”
#   • Technical Specifications/7.2 Data Security:
#     Enforced encryption for personal and transactional data.
###############################################################################
output "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key used for encrypting sensitive data at rest including user information and payment details"
  value       = aws_kms_key.main.arn
  sensitive   = true
}

###############################################################################
# Output: iam_role_arns
# -----------------------------------------------------------------------------
# Description:
#   Exports a map of IAM role ARNs designated for distinct microservices and
#   sub-systems such as the API Gateway and other back-end services. Each role
#   strictly follows least-privilege principles and is restricted to relevant
#   service actions.
#
# Value:
#   A map containing:
#     • aws_iam_role.api_gateway_role.arn
#     • aws_iam_role.services_role.arn
#   Referencing roles that must be declared in main.tf (or associated files),
#   ensuring correct association between services and permissions.
#
# Purpose in Requirements:
#   • Requirement: “Implement role-based access control”
#   • Technical Specifications/7.3.1 Access Control:
#     Each role is tightly scoped to the service’s operational domain.
###############################################################################
output "iam_role_arns" {
  type        = map(string)
  description = "Map of IAM role ARNs for different service components with least privilege access permissions"

  value = {
    api_gateway = aws_iam_role.api_gateway_role.arn
    services    = aws_iam_role.services_role.arn
  }
}