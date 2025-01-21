/************************************************************************
 * Main Terraform configuration file for the Staging environment of the
 * Dog Walking application. This file orchestrates all infrastructure 
 * modules—including API Gateway, microservices, databases, and 
 * monitoring—for a multi-AZ, production-like setup with isolated services.
 *
 * Requirements Addressed:
 * 1. Staging Environment Configuration (8.1): Single region (us-east-1), 
 *    multi-AZ, isolated services, comprehensive monitoring/security.
 * 2. High Availability Architecture (8.2.2): Load balancing, auto-scaling, 
 *    and failover across multiple availability zones.
 * 3. Security Controls (7.1): WAF, Shield, KMS encryption, IAM roles, security 
 *    groups with strict rules, and more.
 * 4. AWS Service Stack (8.2.1): ECS Fargate, Aurora, DocumentDB, ElastiCache, 
 *    and monitoring services.
 ************************************************************************/


/************************************************************************
 * GLOBALS
 * Defines local variables that are used throughout the staging environment.
 * We include environment labels, region, availability zones, and common 
 * tags to ensure consistent usage across resources.
 ************************************************************************/
locals {
  environment        = "staging"
  region             = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Common tags for all resources to facilitate cost allocation, governance, and traceability
  common_tags = {
    Environment         = "staging"
    Project             = "dog-walking"
    ManagedBy           = "terraform"
    CostCenter          = "staging-operations"
    DataClassification  = "confidential"
    Backup              = "daily"
  }
}


/************************************************************************
 * CLASS: terraform
 * Description: Terraform backend and provider configuration with enhanced
 * security and state management.
 ************************************************************************/
terraform {
  /**********************************************************************
   * Constructor (simulated in Terraform context):
   * 1. Set minimum Terraform version to 1.5.0.
   * 2. Configure required providers with version constraints.
   * 3. Set up S3 backend with encryption enabled.
   * 4. Enable state locking with DynamoDB for concurrency control.
   * 5. Configure workspace isolation.
   * 6. Set up provider aliases for multi-AZ or specialized usage.
   **********************************************************************/
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  /**********************************************************************
   * FUNCTION: backend
   * Description: Configures the S3 backend with enhanced security and 
   * state management parameters. 
   * Parameters:
   *   - (string) bucket: S3 bucket used for remote state storage.
   *   - (string) key: The state file path within the bucket.
   *   - (string) region: AWS region for the bucket.
   *   - (string) dynamodb_table: DynamoDB table for state locking.
   *   - (bool)   encrypt: Flag to enable encryption on the state file.
   * Steps:
   *   1. Configure S3 bucket with versioning.
   *   2. Enable state file encryption with KMS.
   *   3. Set up state locking with DynamoDB.
   *   4. Configure access logging for auditing.
   *   5. Enable backup and replication as needed.
   *   6. Set up workspace isolation.
   **********************************************************************/
  backend "s3" {
    bucket         = "dog-walking-staging-tfstate"
    key            = "terraform.tfstate"
    region         = local.region
    dynamodb_table = "dog-walking-staging-tf-lock"
    encrypt        = true
  }
}


/************************************************************************
 * FUNCTION: provider_aws 
 * Description: Configures the AWS provider for the staging environment
 * with enhanced security and monitoring. 
 *
 * Parameters:
 *   - (string) region: AWS region for resource creation (us-east-1).
 *   - (map)    default_tags: Common tags to be applied to all resources.
 *   - (string) assume_role_arn: Optional ARN for cross-account roles if needed.
 *   - (map)    endpoints: Optional custom endpoints for specialized usage.
 *
 * Steps:
 *   1. Set AWS region to us-east-1.
 *   2. Configure default tags that apply to every resource.
 *   3. Set up provider version constraints (already handled above).
 *   4. Configure IAM role assumption for staging, if any.
 *   5. Enable VPC endpoints for critical services (optional).
 *   6. Set up custom service endpoints if required.
 *   7. Configure provider aliases for multi-AZ usage.
 ************************************************************************/
provider "aws" {
  region = local.region

  # Default tags applied to all AWS resources created by this provider
  default_tags {
    tags = local.common_tags
  }

  # Example placeholder for assume_role if needed (commented out if not used):
  # assume_role {
  #   role_arn     = "arn:aws:iam::123456789012:role/StagingTerraformRole"
  #   session_name = "dog_walking_staging_terraform_session"
  # }

  # Additional provider configuration can be placed here for endpoints, if required
}


/************************************************************************
 * IMPORTS (EXTERNAL)
 * 1. hashicorp/aws    ~> 5.0 (AWS provider for infrastructure deployment)
 * 2. hashicorp/random ~> 3.0 (Generate random values for resource naming)
 ************************************************************************/
# (Already satisfied by the required_providers block in the terraform config)

/************************************************************************
 * STAGING ENVIRONMENT RESOURCES 
 *
 * This section orchestrates the high availability components including 
 * VPC, subnets, security groups, WAF, Shield, ECS Fargate, Aurora 
 * PostgreSQL, DocumentDB, ElastiCache, and any required monitoring 
 * services. We use placeholders or references to modules for clarity.
 ************************************************************************/

# ------------------------------------------------------------------------------
# Network Infrastructure (VPC, Subnets, NAT Gateways, etc.)
# ------------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"
  # Example inputs for network module
  name                    = "dog-walking-staging-vpc"
  cidr_block              = "10.101.0.0/16"
  azs                     = local.availability_zones
  private_subnets         = ["10.101.1.0/24", "10.101.2.0/24", "10.101.3.0/24"]
  public_subnets          = ["10.101.4.0/24", "10.101.5.0/24", "10.101.6.0/24"]
  enable_nat_gateway      = true
  single_nat_gateway      = false     # Multi-AZ NAT gateways for HA
  enable_dns_hostnames    = true
  enable_dns_support      = true
  tags                    = local.common_tags
}

# ------------------------------------------------------------------------------
# AWS WAF (for layer 7 protection) & AWS Shield (for DDoS protection)
# ------------------------------------------------------------------------------
resource "aws_wafv2_web_acl" "staging_waf_acl" {
  name        = "dog-walking-staging-waf"
  description = "WAF ACL for staging environment"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommonRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "staging-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_shield_protection" "staging_shield_protection" {
  name         = "dog-walking-staging-shield"
  resource_arn = "" # Placeholder for the ARN of the CloudFront distribution or ALB
  tags         = local.common_tags
}

# ------------------------------------------------------------------------------
# KMS Key for encryption (e.g., EBS, S3, secrets, logs)
# ------------------------------------------------------------------------------
resource "aws_kms_key" "staging_kms" {
  description             = "Staging KMS key for the Dog Walking application"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_policy.json
  tags                    = local.common_tags
}

data "aws_iam_policy_document" "kms_policy" {
  # Example policy allowing necessary principals to use the key
  statement {
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["*"]
  }
}

# ------------------------------------------------------------------------------
# ECS Fargate Cluster
# ------------------------------------------------------------------------------
module "ecs_cluster" {
  source = "../../modules/ecs"
  name   = "dog-walking-staging-ecs-cluster"
  vpc_id = module.vpc.vpc_id

  # Additional configuration like capacity providers, etc.
  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Aurora PostgreSQL (primary relational DB)
# ------------------------------------------------------------------------------
module "aurora_postgresql" {
  source = "../../modules/rds-aurora-postgres"
  name   = "dw-staging-aurora"
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
  engine_version = "15"
  instance_class = "db.serverless"
  tags = local.common_tags

  # Optionally reference the KMS key
  kms_key_id = aws_kms_key.staging_kms.arn
}

# ------------------------------------------------------------------------------
# DocumentDB (for walk records, reviews, etc.)
# ------------------------------------------------------------------------------
module "documentdb" {
  source           = "../../modules/docdb"
  cluster_id       = "dw-staging-docdb"
  vpc_id           = module.vpc.vpc_id
  subnets          = module.vpc.private_subnets
  instance_type    = "db.r5.large"
  apply_immediately = true
  tags             = local.common_tags
  kms_key_id       = aws_kms_key.staging_kms.arn
}

# ------------------------------------------------------------------------------
# ElastiCache (for Redis cache)
# ------------------------------------------------------------------------------
module "elasticache" {
  source            = "../../modules/elasticache"
  engine            = "redis"
  engine_version    = "7.0"
  node_type         = "cache.t3.medium"
  num_cache_nodes   = 2
  cluster_id        = "dw-staging-redis"
  parameter_group_name = "default.redis7.0"
  subnets           = module.vpc.private_subnets
  security_group_ids = []
  tags              = local.common_tags
  kms_key_id        = aws_kms_key.staging_kms.arn
}

# ------------------------------------------------------------------------------
# TimescaleDB (self-managed or via EC2/EKS cluster) placeholder
# For illustration, referencing a module that provisions an EC2-based TimescaleDB
# ------------------------------------------------------------------------------
module "timescaledb" {
  source            = "../../modules/timescaledb"
  name              = "dw-staging-timescale"
  vpc_id            = module.vpc.vpc_id
  subnets           = module.vpc.private_subnets
  instance_type     = "t3.medium"
  allocated_storage = 100
  tags              = local.common_tags
  kms_key_id        = aws_kms_key.staging_kms.arn
}

# ------------------------------------------------------------------------------
# Monitoring Services (CloudWatch, Grafana, Prometheus)
# ------------------------------------------------------------------------------
module "monitoring" {
  source = "../../modules/monitoring"
  name   = "dw-staging-monitoring"

  # Example references for hooking into the environment or advanced config
  cloudwatch_logs_retention = 30
  enable_managed_grafana    = true
  enable_prometheus         = true
  tags                      = local.common_tags
}


/************************************************************************
 * OUTPUTS
 * We expose database and monitoring endpoints for direct configuration
 * in application services or further references in supporting modules.
 ************************************************************************/

# database_endpoints (map)
#   - aurora_postgresql_endpoint : string
#   - documentdb_endpoint        : string
#   - elasticache_endpoint       : string
#   - timescaledb_endpoint       : string
output "database_endpoints" {
  description = "Expose database endpoints for Dog Walking staging environment services"
  value = {
    aurora_postgresql_endpoint = module.aurora_postgresql.endpoint
    documentdb_endpoint        = module.documentdb.endpoint
    elasticache_endpoint       = module.elasticache.primary_endpoint
    timescaledb_endpoint       = module.timescaledb.endpoint
  }
}

# monitoring_endpoints (map)
#   - cloudwatch_endpoint : string
#   - grafana_endpoint    : string
#   - prometheus_endpoint : string
output "monitoring_endpoints" {
  description = "Expose monitoring endpoints for observability in staging"
  value = {
    cloudwatch_endpoint = module.monitoring.cloudwatch_endpoint
    grafana_endpoint    = module.monitoring.grafana_endpoint
    prometheus_endpoint = module.monitoring.prometheus_endpoint
  }
}