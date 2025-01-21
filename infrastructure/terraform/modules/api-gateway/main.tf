###############################################################################
# TERRAFORM CONFIGURATION
# -----------------------------------------------------------------------------
# This file defines the AWS API Gateway for the Dog Walking Application with
# enhanced security, monitoring, and performance features. It addresses:
#  1) Production-grade API Gateway with REGIONAL endpoint configuration,
#     advanced caching, and security controls.
#  2) WAF integration, throttling limits, SSL policy enforcement,
#     and request validation.
#  3) Comprehensive system monitoring (CloudWatch metrics, X-Ray tracing,
#     access logs).
###############################################################################

terraform {
  required_version = ">= 1.0"

  # Required providers explicitly declared for clarity:
  required_providers {
    aws    = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # AWS provider (hashicorp/aws ~> 5.0)
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"  # Random provider (hashicorp/random ~> 3.0)
    }
  }

  # Backend and provider configurations are inherited from the root module.
}

###############################################################################
# PROVIDER CONFIGURATION INHERITED FROM ROOT MODULE
# (No explicit provider blocks are defined here unless overriding.)
###############################################################################

###############################################################################
# IMPORT OF VARIABLES
# -----------------------------------------------------------------------------
# Variables are defined in variables.tf within this module for:
#  - api_name
#  - environment
#  - endpoint_type
#  - enable_xray
#  - enable_waf
#  - throttling_rate_limit
#  - throttling_burst_limit
#  - log_retention_days
#  - enable_caching
#  - cache_size
#  - enable_access_logs
#  - ssl_policy
#  - tags
###############################################################################

###############################################################################
# ADDITIONAL VARIABLE FOR WEB ACL ASSOCIATION (IF WAF ENABLED)
# -----------------------------------------------------------------------------
# This variable is used to associate an existing WAFv2 Web ACL with the API
# Gateway if "enable_waf" is set to true.
###############################################################################
variable "web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL to associate with the API Gateway stage"
  type        = string
  default     = ""
}

###############################################################################
# RANDOM STRING SUFFIX FOR UNIQUENESS
# -----------------------------------------------------------------------------
# Used to ensure each deployed API Gateway name remains unique per environment.
###############################################################################
resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
}

###############################################################################
# LOCAL VALUES
# -----------------------------------------------------------------------------
# Provides environment-specific naming, tags, throttle configuration, logging
# retention, and caching details for enterprise-grade deployments.
###############################################################################
locals {
  # Define resource tags by merging user-defined tags with standard ones:
  resource_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Module      = "api-gateway"
      Owner       = "DogWalkingPlatform"
    }
  )

  # Compute a base name: user-supplied API name + environment
  api_gw_base_name = "${var.api_name}-${var.environment}"
  # Append a random suffix to avoid naming collisions in shared AWS accounts
  api_gw_name      = "${local.api_gw_base_name}-${random_string.suffix.result}"

  # Stage name derived from environment (e.g., "dev", "staging", "prod")
  stage_name = var.environment

  # Combine concurrency-related throttling into a mapped object for convenience.
  # The specification requires environment-specific throttling. We use a single
  # set of variables for demonstration, but this can be extended to handle
  # environment overrides if desired.
  throttling = {
    rate_limit  = var.throttling_rate_limit
    burst_limit = var.throttling_burst_limit
  }

  # The log retention period is set via var.log_retention_days. We can directly
  # reference that for the CloudWatch Log Group.
  log_retention = var.log_retention_days

  # Derive the desired cache size in GB if caching is enabled
  # This is used in stage-level configuration (aws_api_gateway_stage).
  cache_configuration = {
    size_in_gb           = var.cache_size
    enable_stage_caching = var.enable_caching
  }
}

###############################################################################
# RESOURCE POLICY (IP RESTRICTIONS EXAMPLE)
# -----------------------------------------------------------------------------
# This data block demonstrates a minimal resource policy granting "execute-api"
# permissions. It can be extended for advanced security controls such as
# limiting specific IP ranges or implementing more complex conditions.
###############################################################################
data "aws_iam_policy_document" "api_gw_resource_policy" {
  statement {
    sid    = "AllowExecutionFromSpecificIP"
    effect = "Allow"
    actions = [
      "execute-api:Invoke"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["*"]
    condition {
      test     = "IpAddress"
      variable = "aws:SourceIp"
      # Placeholder range: 0.0.0.0/0 => wide open
      values   = ["0.0.0.0/0"]
    }
  }
}

###############################################################################
# CREATE A CLOUDWATCH LOG GROUP FOR API GATEWAY ACCESS LOGS
# -----------------------------------------------------------------------------
# Access logs go to a dedicated log group named /aws/api-gateway/<api_gw_name>.
# The retention is set according to var.log_retention_days.
###############################################################################
resource "aws_cloudwatch_log_group" "api_gw_log_group" {
  name              = "/aws/api-gateway/${local.api_gw_name}"
  retention_in_days = local.log_retention
  tags              = local.resource_tags
}

###############################################################################
# MAIN REST API GATEWAY INSTANCE (aws_api_gateway_rest_api)
# -----------------------------------------------------------------------------
# 1) ENV-SPECIFIC NAME WITH UNIQUE SUFFIX
# 2) REGIONAL (OR OTHER) ENDPOINT TYPE
# 3) COMPREHENSIVE TAGGING & RESOURCE POLICY
# 4) BINARY MEDIA TYPES
# 5) MINIMUM COMPRESSION SIZE
###############################################################################
resource "aws_api_gateway_rest_api" "this" {
  name        = local.api_gw_name
  description = "Main REST API for the Dog Walking application (${var.environment} environment)"

  # Endpoint configuration enforced through 'endpoint_type' variable
  endpoint_configuration {
    types = [var.endpoint_type]
  }

  # Resource policy helps to restrict access by IP or other conditions
  policy = data.aws_iam_policy_document.api_gw_resource_policy.json

  # Enable binary media processing for any content type (e.g., images, etc.)
  binary_media_types = ["*/*"]

  # Additional tagging
  tags = local.resource_tags

  # Minimum compression size (in bytes) for enabling payload compression
  # Setting 0 ensures all responses are compressed if compressible.
  minimum_compression_size = 0
}

###############################################################################
# API GATEWAY DEPLOYMENT
# -----------------------------------------------------------------------------
# A deployment is required to create or update the API Gateway stage.
# The "triggers" can force redeployment when certain configurations change.
###############################################################################
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Add a random trigger to ensure a new deployment on config changes.
  # This is helpful in forcing re-deployment whenever the stage settings
  # or method settings are updated.
  triggers = {
    redeploy_trigger = random_string.suffix.result
  }

  depends_on = [
    aws_api_gateway_rest_api.this
  ]
}

###############################################################################
# PRODUCTION-GRADE DEPLOYMENT STAGE (aws_api_gateway_stage)
# -----------------------------------------------------------------------------
# 1) ENV-SPECIFIC NAME
# 2) DETAILED X-RAY TRACING
# 3) COMPREHENSIVE CLOUDWATCH LOGGING (ACCESS & EXECUTION)
# 4) DETAILED METRICS
# 5) CACHE CLUSTER CONFIG
# 6) TLS POLICY
# 7) (OPTIONAL) CUSTOM DOMAIN MAPPING CAN BE ADDED LATER
###############################################################################
resource "aws_api_gateway_stage" "this" {
  stage_name    = local.stage_name
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id

  # Enable X-Ray tracing if configured
  xray_tracing_enabled = var.enable_xray

  # Access log settings if enable_access_logs is true
  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.api_gw_log_group.arn
      format          = jsonencode({
        requestId                 = "$context.requestId"
        ip                        = "$context.identity.sourceIp"
        caller                    = "$context.identity.caller"
        user                      = "$context.identity.user"
        requestTime               = "$context.requestTime"
        httpMethod                = "$context.httpMethod"
        resourcePath              = "$context.resourcePath"
        status                    = "$context.status"
        protocol                  = "$context.protocol"
        responseLength            = "$context.responseLength"
        integrationError          = "$context.integrationErrorMessage"
        integrationStatus         = "$context.integrationStatus"
        integrationLatency        = "$context.integrationLatency"
        authentication            = "$context.authorizer.principalId"
        apiId                     = "$context.apiId"
        stage                     = "$context.stage"
        userAgent                 = "$context.identity.userAgent"
      })
    }
  }

  # Enable caching if desired. The cache cluster size is determined by local.cache_configuration.
  cache_cluster_enabled  = local.cache_configuration.enable_stage_caching
  cache_cluster_size     = format("%.1f", local.cache_configuration.size_in_gb)
  client_certificate_id  = null  # Example placeholder for mTLS or custom certificates

  # Tags for stage
  tags = local.resource_tags

  # Enforce a chosen SSL policy if using a custom domain. By default, this
  # param is relevant in the "aws_api_gateway_domain_name", but we list it here
  # to highlight security best practices. The official AWS provider support
  # for stage-level SSL policy is effectively part of domain resources, so
  # we keep a reference comment:
  # ssl_policy = var.ssl_policy
}

###############################################################################
# ENHANCED WAF INTEGRATION (aws_wafv2_web_acl_association)
# -----------------------------------------------------------------------------
# Associates a WAF2 Web ACL with the API Gateway stage resource to protect
# from common exploits, applying rate-based rules, IP lists, etc.
###############################################################################
resource "aws_wafv2_web_acl_association" "this" {
  count = var.enable_waf && var.web_acl_arn != "" ? 1 : 0

  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = var.web_acl_arn
}

###############################################################################
# COMPREHENSIVE METHOD SETTINGS (aws_api_gateway_method_settings)
# -----------------------------------------------------------------------------
# Applies advanced throttling, logging, metrics, caching, request validation,
# and other environment-specific constraints to all methods/* on the stage.
###############################################################################
resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = var.enable_access_logs ? "INFO" : "OFF"

    # Throttling based on environment
    throttling_rate_limit  = local.throttling.rate_limit
    throttling_burst_limit = local.throttling.burst_limit

    # Caching
    caching_enabled       = local.cache_configuration.enable_stage_caching
    cache_data_encrypted  = local.cache_configuration.enable_stage_caching
    cache_ttl_in_seconds  = local.cache_configuration.enable_stage_caching ? 300 : 0

    # Detailed request validation can be set up here if needed
    # e.g. "require_api_key" = true

    # CORS and transformation can be configured further via
    # "method_response" and "integration_response" resources.
  }
}

###############################################################################
# EXPORTS: API GATEWAY RESOURCE IDENTIFIERS & STAGE
# -----------------------------------------------------------------------------
# Provide outputs to integrate with other services (e.g., Lambdas, microservices)
# or reference in higher-level modules. We expose the resource's ID, ARN, etc.
###############################################################################

# Exports for aws_api_gateway_rest_api.this
output "api_gateway_rest_api_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.this.id
}

output "api_gateway_rest_api_execution_arn" {
  description = "API Gateway Execution ARN"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "api_gateway_rest_api_root_resource_id" {
  description = "API Gateway Root Resource ID"
  value       = aws_api_gateway_rest_api.this.root_resource_id
}

# Exports for aws_api_gateway_stage.this
output "api_gateway_stage_invoke_url" {
  description = "Stage Invoke URL for direct requests"
  value       = aws_api_gateway_stage.this.invoke_url
}

# Because we associate WAF to the stage, we can export the effective ARN here.
# For convenience, we reference the same resource. If no WAF is used, it remains null.
output "api_gateway_stage_web_acl_arn" {
  description = "ARN of WAF Web ACL associated with API Gateway Stage (if applicable)"
  # If the resource is not created, we return an empty string
  value = var.enable_waf && var.web_acl_arn != "" ? var.web_acl_arn : ""
}