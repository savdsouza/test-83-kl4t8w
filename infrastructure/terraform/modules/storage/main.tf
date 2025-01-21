###############################################################################
# Terraform Configuration:
#   - This module provisions an Amazon S3 bucket and associated configurations
#     for storing media files related to the dog walking application.
#   - Ensures compliance with encryption, versioning, lifecycle, and security
#     requirements as described in the technical and JSON specifications.
###############################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket.media_bucket
# PURPOSE:
#   Primary S3 bucket to store application media (e.g., walk photos).
#   Enforces naming convention based on environment and project name.
#   Tags provide essential metadata for environment, data classification,
#   cost center, etc.
###############################################################################
resource "aws_s3_bucket" "media_bucket" {
  bucket       = "${var.project_name}-media-${var.environment}"
  force_destroy = false

  tags = {
    Name              = "${var.project_name}-media-${var.environment}"
    Environment       = var.environment
    Purpose           = "Media storage for dog walking application"
    DataClassification= "Sensitive"
    CostCenter        = "MediaStorage"
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket_intelligent_tiering_configuration.media_bucket_tiering
# PURPOSE:
#   Configures intelligent tiering to automatically transition objects
#   to the DEEP_ARCHIVE_ACCESS tier after 180 days for cost optimization.
###############################################################################
resource "aws_s3_bucket_intelligent_tiering_configuration" "media_bucket_tiering" {
  bucket = aws_s3_bucket.media_bucket.id
  name   = "MediaTiering"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket_versioning.media_bucket_versioning
# PURPOSE:
#   Enables S3 bucket versioning to maintain object versions and protect
#   data integrity. MFA delete is set to prevent accidental or malicious
#   deletions without authorized MFA.
###############################################################################
resource "aws_s3_bucket_versioning" "media_bucket_versioning" {
  bucket = aws_s3_bucket.media_bucket.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket_server_side_encryption_configuration.media_bucket_encryption
# PURPOSE:
#   Forces AES-256 server-side encryption for all objects uploaded to the bucket.
#   bucket_key_enabled reduces cost by decreasing the number of KMS requests.
###############################################################################
resource "aws_s3_bucket_server_side_encryption_configuration" "media_bucket_encryption" {
  bucket = aws_s3_bucket.media_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket_lifecycle_rule.media_lifecycle
# PURPOSE:
#   Establishes a detailed lifecycle policy covering:
#     - Transition to STANDARD_IA storage after var.media_retention_days days.
#     - Further transition to GLACIER after 180 days.
#     - Deletes objects fully at var.archive_retention_days days.
#     - Noncurrent versions are retained for 90 days before removal.
###############################################################################
resource "aws_s3_bucket_lifecycle_rule" "media_lifecycle" {
  bucket = aws_s3_bucket.media_bucket.id
  id     = "media_transition"
  enabled = true
  prefix  = "media/"

  transition {
    days          = var.media_retention_days
    storage_class = "STANDARD_IA"
  }

  transition {
    days          = 180
    storage_class = "GLACIER"
  }

  expiration {
    days = var.archive_retention_days
  }

  noncurrent_version_expiration {
    days = 90
  }
}

###############################################################################
# RESOURCE: aws_s3_bucket_public_access_block.media_bucket_public_access
# PURPOSE:
#   Exhaustively blocks all forms of public access to ensure that sensitive
#   media files are not exposed to the internet. Aligns with best practices
#   for S3 bucket security.
###############################################################################
resource "aws_s3_bucket_public_access_block" "media_bucket_public_access" {
  bucket                  = aws_s3_bucket.media_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# RESOURCE: aws_s3_bucket_logging.media_bucket_logging
# PURPOSE:
#   Enables detailed access logs for the media bucket, stored within the
#   same bucket under a specific prefix. Useful for audit trails and
#   security incident investigations.
###############################################################################
resource "aws_s3_bucket_logging" "media_bucket_logging" {
  bucket        = aws_s3_bucket.media_bucket.id
  target_bucket = aws_s3_bucket.media_bucket.id
  target_prefix = "access-logs/${var.environment}/"
}

###############################################################################
# OUTPUTS:
#   Exports S3 bucket details (ID, ARN, and Domain Name) to allow referencing
#   from parent modules or external projects requiring knowledge of the media
#   bucket's key properties.
###############################################################################
output "media_bucket_id" {
  description = "The name (ID) of the media S3 bucket."
  value       = aws_s3_bucket.media_bucket.id
}

output "media_bucket_arn" {
  description = "The ARN of the media S3 bucket."
  value       = aws_s3_bucket.media_bucket.arn
}

output "media_bucket_domain_name" {
  description = "The bucket domain name for the media S3 bucket."
  value       = aws_s3_bucket.media_bucket.bucket_domain_name
}