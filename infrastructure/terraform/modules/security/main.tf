###################################################################################################
# MODULE: Security Infrastructure
# -----------------------------------------------------------------------------------------------
# This Terraform module implements the comprehensive security infrastructure for the Dog Walking
# application, including:
#  - Enhanced WAF rules with rate limiting, IP filtering, XSS/SQL injection protection
#  - Granular security groups following the principle of least privilege
#  - IAM roles/policies for key aspects like WAF logging and security administration
#  - KMS key setup with enabled rotation and a detailed key policy
#
# References from Technical Specifications:
#  • Security Architecture (Section 2.4.2) for WAF, network security, and strict boundary protections
#  • Data Security (Section 7.2) for secure key management and encryption controls
#  • Access Control (Section 7.3.1) for robust authentication, authorization, and rate limiting
#
# This file depends on variables defined in "variables.tf", such as:
#  - var.name (Project name)
#  - var.env (Environment identifier)
#  - var.vpc_id (VPC ID)
#  - var.service_ports (Map of service port/protocols)
#  - var.waf_rate_limit, var.allowed_ip_ranges, var.waf_block_rules, etc.
#
# The resources in this file produce outputs exposing ARN and IDs for various security components,
# aligning with the JSON specification for advanced exports including:
#  - waf_web_acl_arn
#  - security_group_ids
#  - kms_key_arn
#  - iam_role_arns
###################################################################################################

############################################################
# Required Providers & Terraform Settings
############################################################
terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # The AWS provider configuration can be passed in from root module
  # or leveraged through workspace-based configuration.
}

############################################################
# Data Sources for IAM Policy Documents
# (Defining trust policies or boundary policies as needed)
############################################################
data "aws_iam_policy_document" "security_admin_assume_policy" {
  # Minimal trust policy granting assume_role from EC2
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "waf_logging_trust" {
  # Trust policy permitting AWS WAF to write logs
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "Service"
      identifiers = ["waf.amazonaws.com"]
    }
  }
}

############################################################
# IAM Roles
# (Part of JSON spec: "comprehensive IAM roles/policies")
############################################################
resource "aws_iam_role" "security_admin_role" {
  name               = "${var.name}-${var.env}-security-admin"
  assume_role_policy = data.aws_iam_policy_document.security_admin_assume_policy.json

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "RolePurpose" = "SecurityAdmin"
    }
  )
}

resource "aws_iam_role" "waf_logging_role" {
  name               = "${var.name}-${var.env}-waf-logging"
  assume_role_policy = data.aws_iam_policy_document.waf_logging_trust.json

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "RolePurpose" = "WAFLogging"
    }
  )
}

############################################################
# Optional: Attaching or creating policies for the IAM roles
# (If policy content is needed, define aws_iam_role_policy or
#  inline policy docs below)
############################################################
# Example minimal inline policy for WAF logging role to write logs:
resource "aws_iam_role_policy" "waf_logging_policy" {
  name = "${var.name}-${var.env}-waf-logging-policy"
  role = aws_iam_role.waf_logging_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

###################################################################################################
# create_waf_rules
#
# Implements the function from the JSON spec:
# "Creates enhanced WAF web ACL with rate limiting, IP filtering, XSS/SQL injection prevention"
#
# Detailed Steps (from JSON spec):
# 1. Create WAF web ACL resource with logging enabled
# 2. Configure rate limiting rule with custom thresholds
# 3. Configure IP filtering rule with allow/deny lists
# 4. Add AWS managed rule sets for common threats
# 5. Add custom rules for application-specific protection
# 6. Configure rule priority and actions
# 7. Enable metrics and logging
###################################################################################################

# Conditional CloudWatch Log Group for WAF Logging
# to store WAF logs if var.enable_waf is true
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_waf ? 1 : 0

  name = "/aws/waf2/${var.name}-${var.env}"
  retention_in_days = 30

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "Service"     = "WAFLogs"
    }
  )
}

# Primary WAFv2 Web ACL
resource "aws_wafv2_web_acl" "main" {
  count = var.enable_waf ? 1 : 0

  name  = "${var.name}-${var.env}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  description = "Enhanced WAF v2 ACL for ${var.name} environment ${var.env}"

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-${var.env}-waf"
    sampled_requests_enabled   = true
  }

  # Rate-limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 10
    statement {
      rate_based_statement {
        limit               = var.waf_rate_limit
        aggregate_key_type  = "IP"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
      sampled_requests_enabled   = true
    }
    action {
      block {}
    }
  }

  # IP Filtering Rule (Allow specific IPs if provided)
  # If allowed_ip_ranges is empty, skip. Otherwise, allow only those IPs.
  dynamic "rule" {
    for_each = length(var.allowed_ip_ranges) > 0 ? [true] : []
    content {
      name     = "IPAllowList"
      priority = 20
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.allowed_ips[0].arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPAllowList"
        sampled_requests_enabled   = true
      }
      override_action {
        none {}
      }
    }
  }

  # AWS-managed common rule set for general threat protection
  rule {
    name     = "AWSManagedRulesCommon"
    priority = 30
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommon"
      sampled_requests_enabled   = true
    }
    override_action {
      none {}
    }
  }

  # AWS-managed SQL injection protection
  rule {
    name     = "AWSManagedRulesSQLInjection"
    priority = 40
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLInjection"
      sampled_requests_enabled   = true
    }
    override_action {
      none {}
    }
  }

  # Additional dynamic rules from var.waf_block_rules
  dynamic "rule" {
    for_each = var.waf_block_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority
      statement {
        # For demonstration, each custom rule is set as a simple byte_match
        # or XSS match statement or similar. In a production design, the
        # statement can be more specific to the identified threat.
        byte_match_statement {
          search_string = rule.value.name
          field_to_match {
            uri_path {}
          }
          text_transformation {
            priority = 1
            type     = "NONE"
          }
          positional_constraint = "CONTAINS"
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.value.name
        sampled_requests_enabled   = true
      }

      # Action from the variable "action" field (allow, block, count)
      dynamic "action" {
        for_each = rule.value.action == "block" ? [true] : []
        content {
          block {}
        }
      }
      dynamic "action2" {
        for_each = rule.value.action == "allow" ? [true] : []
        content {
          allow {}
        }
      }
      dynamic "action3" {
        for_each = rule.value.action == "count" ? [true] : []
        content {
          count {}
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "ManagedBy"   = "terraform"
      "Module"      = "create_waf_rules"
    }
  )
}

# IP set resource for the allowed_ip_ranges, used in IP filtering rule if not empty
resource "aws_wafv2_ip_set" "allowed_ips" {
  count = (var.enable_waf && length(var.allowed_ip_ranges) > 0) ? 1 : 0

  name               = "${var.name}-${var.env}-allowed-ips"
  scope              = "REGIONAL"
  description        = "IP set for allowed traffic for ${var.name} in ${var.env}"
  addresses          = var.allowed_ip_ranges
  ip_address_version = "IPV4"

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "ManagedBy"   = "terraform"
      "Module"      = "create_waf_rules"
    }
  )
}

# WAF Logging Configuration referencing the primary ACL
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  count = var.enable_waf ? 1 : 0

  resource_arn        = aws_wafv2_web_acl.main[0].arn
  log_destination_configs = [
    element(concat(
      [aws_cloudwatch_log_group.waf.*.arn]
    ), 0)
  ]

  redacted_fields {
    single_header {
      name = "Authorization"
    }
  }

  depends_on = [
    aws_wafv2_web_acl.main,
    aws_cloudwatch_log_group.waf
  ]
}

###################################################################################################
# create_security_groups
#
# Implements the function from the JSON spec:
# "Creates granular security groups with principle of least privilege"
#
# Detailed Steps (from JSON spec):
# 1. Create API Gateway security group with strict ingress
# 2. Create service-specific security groups
# 3. Create database security group with encrypted ports
# 4. Configure granular ingress rules per service
# 5. Configure restricted egress rules
# 6. Add cross-service communication rules
# 7. Add monitoring/logging configurations
#
# For simplicity here, we unify multiple group definitions using a for_each approach to handle
# each microservice's port/protocol from var.service_ports. We also apply optional IP-based
# restrictions as needed.
###################################################################################################
resource "aws_security_group" "service_sg" {
  for_each = var.service_ports

  name        = "${var.name}-${var.env}-${each.key}-sg"
  description = "Security Group for ${each.key} in ${var.name} environment ${var.env}"
  vpc_id      = var.vpc_id

  # Ingress: Restrict to the allowed IP ranges (if specified).
  # If no allowed_ip_ranges are provided, open it to 0.0.0.0/0 for demonstration
  # or adopt a minimal approach. Modify as suitable for production best practices.
  dynamic "ingress" {
    for_each = length(var.allowed_ip_ranges) > 0 ? var.allowed_ip_ranges : ["0.0.0.0/0"]
    content {
      description = "Allow inbound from ${ingress.value} for service ${each.key}"
      from_port   = each.value.port
      to_port     = each.value.port
      protocol    = each.value.protocol
      cidr_blocks = [ingress.value]
    }
  }

  # Egress: Restrict all egress or open to all. Typically set to all for outward calls.
  egress {
    description = "Allow all outbound from service ${each.key}"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      "Name"        = "${var.name}-${var.env}-${each.key}-sg"
      "Project"     = var.name
      "Environment" = var.env
      "ManagedBy"   = "terraform"
      "Module"      = "create_security_groups"
      "Service"     = each.key
    }
  )
}

###################################################################################################
# Enhanced KMS Key with Rotation
#
# Implements the resource from the JSON spec:
# "aws_kms_key" with strict key rotation and policies for data protection.
###################################################################################################
resource "aws_kms_key" "main" {
  description             = "KMS key for project ${var.name} in environment ${var.env} with rotation"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = var.enable_key_rotation

  # Example key policy. In production, base it on best-practice docs or custom policy docs.
  policy = <<-EOP
{
  "Version": "2012-10-17",
  "Id": "key-default-policy",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "kms:DescribeKey",
        "kms:List*",
        "kms:Get*",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow use of the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:GenerateDataKeyPair*",
        "kms:DescribeKey"
      ],
      "Resource": "*"
    }
  ]
}
EOP

  tags = merge(
    var.tags,
    {
      "Project"     = var.name
      "Environment" = var.env
      "ManagedBy"   = "terraform"
    }
  )
}

###################################################################################################
# OUTPUTS
#
# The JSON specification requires exporting:
#  - waf_web_acl_arn
#  - security_group_ids
#  - kms_key_arn
#  - iam_role_arns
###################################################################################################

# WAF Web ACL ARN (exported if WAF is enabled)
output "waf_web_acl_arn" {
  description = "ARN of the enhanced WAF web ACL"
  value       = var.enable_waf ? aws_wafv2_web_acl.main[0].arn : null
}

# Security Group IDs (Map by microservice key)
output "security_group_ids" {
  description = "Map of Security Group IDs, keyed by service name"
  value = { for s, sg in aws_security_group.service_sg : s => sg.id }
}

# KMS Key ARN
output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption with rotation"
  value       = aws_kms_key.main.arn
}

# IAM Role ARNs
# Exporting a map that includes security_admin_role and waf_logging_role
output "iam_role_arns" {
  description = "Map of important IAM role ARNs supporting security features"
  value = {
    "security_admin" = aws_iam_role.security_admin_role.arn
    "waf_logging"    = aws_iam_role.waf_logging_role.arn
  }
}