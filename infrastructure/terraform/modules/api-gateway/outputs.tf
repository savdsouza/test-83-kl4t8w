###############################################################################
# TERRAFORM OUTPUT DEFINITIONS FOR THE API GATEWAY MODULE
# -----------------------------------------------------------------------------
# This file exposes essential attributes of the created AWS API Gateway
# to enable integration with other modules and services, ensuring
# production-grade security and multi-environment support.
###############################################################################

###############################################################################
# OUTPUT: API GATEWAY ID
# -----------------------------------------------------------------------------
# Provides the unique ID of the created API Gateway, which can be used
# to link with IAM policies, Route53 configurations, or additional
# microservices. This identifier is referenced frequently for resource
# associations such as usage plans, integrations, or custom domains.
###############################################################################
output "api_gateway_id" {
  description = "The unique identifier of the created API Gateway instance for service integration and resource association"
  value       = aws_api_gateway_rest_api.this.id
}

###############################################################################
# OUTPUT: API GATEWAY EXECUTION ARN
# -----------------------------------------------------------------------------
# Exposes the ARN of the API Gateway execution, often used to grant
# Lambda invoke permissions or configure service mesh routing in secured
# environments. Marked as sensitive to avoid leakage of resource-specific
# ARNs in less secure contexts such as logs or external dashboards.
###############################################################################
output "api_gateway_execution_arn" {
  description = "The execution ARN of the API Gateway used for granting invoke permissions to Lambda functions and configuring service mesh routing"
  value       = aws_api_gateway_rest_api.this.execution_arn
  sensitive   = true
}

###############################################################################
# OUTPUT: API GATEWAY INVOKE URL
# -----------------------------------------------------------------------------
# Provides the base URL for clients to invoke API Gateway endpoints,
# including the deployed stage name and region-specific information.
# Can be consumed by front-end applications, microservices, or automation
# workflows that require direct access to the API in the assigned environment.
###############################################################################
output "api_gateway_invoke_url" {
  description = "The environment-specific base URL for invoking API Gateway endpoints"
  value       = aws_api_gateway_stage.this.invoke_url
  sensitive   = false
}

###############################################################################
# OUTPUT: API GATEWAY NAME
# -----------------------------------------------------------------------------
# Represents the user-defined name of the API Gateway instance, concatenated
# with environment suffixes for uniqueness. Helpful for tagging,
# monitoring, or referencing in CloudWatch dashboards.
###############################################################################
output "api_gateway_name" {
  description = "The name of the API Gateway instance for reference in monitoring, logging, and resource tagging"
  value       = aws_api_gateway_rest_api.this.name
}

###############################################################################
# OUTPUT: API GATEWAY STAGE NAME
# -----------------------------------------------------------------------------
# Provides the name of the stage where the API has been deployed. Essential
# for environment-based routing, environment-tiered permissions, and
# usage plan differentiation.
###############################################################################
output "api_gateway_stage_name" {
  description = "The name of the deployed API Gateway stage for environment-specific routing and configuration"
  value       = aws_api_gateway_stage.this.stage_name
}