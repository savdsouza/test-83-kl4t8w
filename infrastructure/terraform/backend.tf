###############################################################################
# Terraform Backend Configuration for State Management
# Using AWS S3 (with versioning, cross-region replication, server-side
# encryption) and AWS DynamoDB (with auto-scaling and point-in-time recovery)
# for state locking. This setup enforces high availability, strong security,
# and compliance requirements including MFA delete, KMS encryption, and
# CloudTrail logging for auditing.
###############################################################################

###############################################################################
# External Import Reference:
# We rely on the "hashicorp/terraform" external package, version "~> 1.6.0"
# for core Terraform functionality. AWS provider configurations are imported
# from provider.tf (aws_provider_config).
###############################################################################
terraform {
  required_version = ">= 1.6.0"

  # Configure the S3 backend for Terraform State
  backend "s3" {
    # Core state storage parameters
    bucket         = "dogwalking-terraform-state"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "dogwalking-terraform-locks"

    # Workspace prefix for isolating different environments (dev, staging, prod)
    workspace_key_prefix = "env"
  }
}

###############################################################################
# S3 Bucket Resource for Terraform State
# - ACL set to private
# - Versioning enforced with MFA delete
# - KMS-based encryption
# - Detailed server-side encryption rules
###############################################################################
resource "aws_s3_bucket" "terraform_state" {
  # Bucket name must match the backend config
  bucket = "dogwalking-terraform-state"
  acl    = "private"

  # Enforce best practices to prevent public exposure
  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
  restrict_public_buckets = true

  # Tags for governance, cost tracking, and accountability
  tags = {
    Name        = "DogWalkingTerraformState"
    Environment = terraform.workspace
    Project     = "DogWalking"
    ManagedBy   = "Terraform"
    Security    = "High"
  }
}

###############################################################################
# Enable Versioning on the S3 Bucket (MFA Delete Included)
###############################################################################
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
    # MFA Delete ensures privileged MFA usage to remove specific versions
    mfa_delete = true
  }
}

###############################################################################
# Server-Side Encryption Configuration for S3 Bucket
# - Using AWS KMS with the default master key (aws/s3)
###############################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_sse" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm   = "aws:kms"
      kms_master_key_id = "aws/s3"
    }
  }
}

###############################################################################
# Cross-Region Replication for High Availability
# - Replicates the Terraform state to a replica bucket in us-west-2
# - Requires a dedicated IAM role with replication permissions
###############################################################################
resource "aws_s3_bucket_replication_configuration" "terraform_state_replication" {
  bucket = aws_s3_bucket.terraform_state.id
  role   = "arn:aws:iam::ACCOUNT_ID:role/terraform-state-replication"

  rule {
    id     = "state-replication"
    status = "Enabled"

    filter {
      prefix = ""
    }

    destination {
      bucket              = "arn:aws:s3:::dogwalking-terraform-state-replica"
      storage_class       = "STANDARD"
      replica_kms_key_id  = "arn:aws:kms:us-west-2:ACCOUNT_ID:key/replica-key"
    }
  }
}

###############################################################################
# DynamoDB Table for Terraform State Locking
# - LockID attribute used for concurrency control
# - Provisioned mode with auto-scaling
# - Server-side encryption enabled
# - Point-in-time recovery for compliance
# - TTL for old lock records
###############################################################################
resource "aws_dynamodb_table" "terraform_state_locks" {
  name           = "dogwalking-terraform-locks"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Enable Point-in-Time Recovery (PITR) for compliance
  point_in_time_recovery {
    enabled = true
  }

  # Enable TTL so that old lock records can be automatically removed
  ttl {
    attribute_name = "ExpiresAt"
    enabled        = true
  }

  # Tagging for cost tracking and environment identification
  tags = {
    Name        = "TerraformStateLocks"
    Environment = terraform.workspace
    Project     = "DogWalking"
    ManagedBy   = "Terraform"
    Security    = "High"
  }
}

###############################################################################
# Auto Scaling Configuration for DynamoDB Read Capacity
# - Scales between 5 and 100 read capacity units
# - Utilizes a target value of 70% for read utilization
###############################################################################
resource "aws_appautoscaling_target" "terraform_state_locks_read" {
  max_capacity       = 100
  min_capacity       = 5
  service_namespace  = "dynamodb"
  resource_id        = "table/${aws_dynamodb_table.terraform_state_locks.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
}

resource "aws_appautoscaling_policy" "terraform_state_locks_read_policy" {
  name                    = "terraformStateLocksDDBReadAutoScalingPolicy"
  policy_type             = "TargetTrackingScaling"
  service_namespace       = aws_appautoscaling_target.terraform_state_locks_read.service_namespace
  resource_id             = aws_appautoscaling_target.terraform_state_locks_read.resource_id
  scalable_dimension      = aws_appautoscaling_target.terraform_state_locks_read.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

###############################################################################
# Auto Scaling Configuration for DynamoDB Write Capacity
# - Scales between 5 and 100 write capacity units
# - Utilizes a target value of 70% for write utilization
###############################################################################
resource "aws_appautoscaling_target" "terraform_state_locks_write" {
  max_capacity       = 100
  min_capacity       = 5
  service_namespace  = "dynamodb"
  resource_id        = "table/${aws_dynamodb_table.terraform_state_locks.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
}

resource "aws_appautoscaling_policy" "terraform_state_locks_write_policy" {
  name               = "terraformStateLocksDDBWriteAutoScalingPolicy"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.terraform_state_locks_write.service_namespace
  resource_id        = aws_appautoscaling_target.terraform_state_locks_write.resource_id
  scalable_dimension = aws_appautoscaling_target.terraform_state_locks_write.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

###############################################################################
# CloudTrail for Audit Logging
# - Tracks API calls related to S3 and DynamoDB usage for state management
# - Multi-region trail for comprehensive coverage
# - Logs retained in CloudWatch for 365 days
###############################################################################
resource "aws_cloudwatch_log_group" "terraform_state_trail" {
  name              = "/aws/cloudtrail/dogwalking-terraform-state"
  retention_in_days = 365

  # Optionally encrypt these logs with a custom KMS key
  # Replace with valid KMS key ARN if required:
  # kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/CLOUDTRAIL-LOGS-KEY"
}

resource "aws_cloudtrail" "terraform_state_trail" {
  name                          = "dogwalking-terraform-state-trail"
  s3_bucket_name                = aws_s3_bucket.terraform_state.bucket
  s3_key_prefix                 = "cloudtrail-logs"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  enable_logging                = true

  # For encryption at rest of CloudTrail logs, specify KMS key if needed:
  # kms_key_id = "arn:aws:kms:us-east-1:ACCOUNT_ID:key/CLOUDTRAIL-KEY"

  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.terraform_state_trail.arn

  # Replace with a valid IAM role ARN for publishing CloudTrail logs to CloudWatch
  # (requires PutLogEvents permission):
  cloud_watch_logs_role_arn = "arn:aws:iam::ACCOUNT_ID:role/terraform-state-cloudtrail-logs"
}

###############################################################################
# Security Alert Configuration
# - SNS Topic for event-driven alerts (e.g., unauthorized access, encryption 
#   changes, replication failures). Additional event rules and targets could
#   be defined here to finalize alerting pipelines. Shown below are stubs.
###############################################################################
resource "aws_sns_topic" "security_alerts" {
  name = "dogwalking-terraform-security-alerts"
}

resource "aws_cloudwatch_event_rule" "replication_failures_rule" {
  name        = "S3ReplicationFailures"
  description = "Triggers on any S3 replication failure events"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    "detail-type" = ["AWS API Call via CloudTrail"]
    detail      = {
      eventName  = ["ReplicateObject", "ReplicateDelete"]
      errorCode  = ["ReplicationFailure"]
    }
  })
}

resource "aws_cloudwatch_event_target" "replication_failures_target" {
  rule = aws_cloudwatch_event_rule.replication_failures_rule.name
  arn  = aws_sns_topic.security_alerts.arn
}

###############################################################################
# Optional - Additional rules can be similarly created for unauthorized access
# and encryption changes, each referencing the same SNS Topic or a different one.
# End of backend.tf
###############################################################################