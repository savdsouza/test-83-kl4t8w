###############################################################################
# Terraform Configuration for Multi-Region AWS Deployment with High Availability
# and Security Features for the Dog Walking Platform. This file configures the
# AWS provider (primary in US East and secondary in US West), along with the
# random and null providers, to ensure robust, highly available infrastructure.
###############################################################################

###############################################################################
# Required Providers
###############################################################################
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # AWS provider for infrastructure deployment with multi-region support
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0" # Random provider for generating unique resource identifiers and names
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0" # Null provider for managing resource dependencies and provisioning
    }
  }
}

###############################################################################
# Local Variables
###############################################################################
locals {
  # Environment name derived from workspace for consistent resource naming
  environment = terraform.workspace
}

###############################################################################
# Primary AWS Provider Configuration
# - Region: us-east-1
# - High Availability: Multi-AZ, multi-region foundation
# - Security Configuration: assume_role with external_id, enforced encryption
# - Universal Resource Tagging for governance and cost tracking
###############################################################################
provider "aws" {
  region                  = "us-east-1"
  s3_force_path_style     = false
  skip_credentials_validation = false
  skip_metadata_api_check = false
  skip_region_validation  = false

  # Secure cross-account access with external ID for additional safety
  assume_role {
    role_arn     = var.aws_role_arn
    session_name = "terraform-${local.environment}"
    external_id  = var.aws_external_id
  }

  # Default tags applied to all AWS resources, ensuring consistent categorization
  default_tags {
    tags = {
      Environment   = local.environment
      ManagedBy     = "Terraform"
      Project       = "DogWalking"
      Region        = "Primary"
      SecurityLevel = "High"
      BackupEnabled = "true"
    }
  }
}

###############################################################################
# Secondary AWS Provider Configuration
# - Alias: secondary
# - Region: us-west-2
# - High Availability: Cross-region redundancy for disaster recovery
# - Security Configuration: assume_role with external_id, enforced encryption
# - Universal Resource Tagging for governance and cost tracking
###############################################################################
provider "aws" {
  alias                  = "secondary"
  region                 = "us-west-2"
  s3_force_path_style    = false
  skip_credentials_validation = false
  skip_metadata_api_check = false
  skip_region_validation = false

  # Secure cross-account access with external ID for additional safety
  assume_role {
    role_arn     = var.aws_role_arn
    session_name = "terraform-${local.environment}"
    external_id  = var.aws_external_id
  }

  # Default tags applied to all AWS resources in the secondary region
  default_tags {
    tags = {
      Environment   = local.environment
      ManagedBy     = "Terraform"
      Project       = "DogWalking"
      Region        = "Secondary"
      SecurityLevel = "High"
      BackupEnabled = "true"
    }
  }
}

###############################################################################
# Random Provider Configuration
# This provider is used to generate unique values (e.g., random identifiers) to
# maintain globally unique resource naming and mitigate naming collisions in
# multi-region deployments.
###############################################################################
provider "random" {
  # ~> 3.0 ensures capability for advanced random functionality
  # Used for generating unique names, tokens, and seeds.
}

###############################################################################
# Null Provider Configuration
# This provider assists in creating ‘null_resource’ blocks to handle specialized
# provisioning, triggers, and data dependencies within the infrastructure code.
###############################################################################
provider "null" {
  # ~> 3.0 ensures capability for resource triggers and provisioning steps
}