###############################################################################
# Dog Walking Platform - Terraform Version Requirements
#
# EXPORT: terraform_version_requirements
# This file strictly defines the required versions of Terraform and all relevant
# providers, ensuring:
#   1. Infrastructure Version Control for consistency across environments.
#   2. Multi-Region Deployment support via AWS provider configuration.
#   3. Security Standards through locked provider versions containing the latest
#      security patches and compliance capabilities.
###############################################################################

###############################################################################
# Terraform Block
# - required_version enforces the exact Terraform range to guarantee compatibility
#   with AWS provider features and overall system security.
# - required_providers locks down the AWS, random, and null providers to ensure
#   stable, secure multi-region infrastructure deployments.
###############################################################################
terraform {
  # Enforces Terraform version between 1.6.0 (inclusive) and 1.7.0 (exclusive)
  required_version = ">=1.6.0, <1.7.0"

  required_providers {
    #############################################################################
    # AWS Provider
    # Source     : hashicorp/aws
    # Version    : ~> 5.0  (which covers >= 5.0.0 and < 6.0.0)
    # Purpose    : Supports required AWS services, multi-region deployment, and
    #              security features (e.g., encryption, advanced IAM roles).
    #############################################################################
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    #############################################################################
    # Random Provider
    # Source     : hashicorp/random
    # Version    : ~> 3.0  (which covers >= 3.0.0 and < 4.0.0)
    # Purpose    : Generates secure random values for resource names and tokens
    #              to avoid naming collisions across regions.
    #############################################################################
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }

    #############################################################################
    # Null Provider
    # Source     : hashicorp/null
    # Version    : ~> 3.0  (which covers >= 3.0.0 and < 4.0.0)
    # Purpose    : Manages lifecycle hooks and triggers, providing flexible
    #              integration points for specialized workflows like multi-region
    #              synchronization scripts or custom validations.
    #############################################################################
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}