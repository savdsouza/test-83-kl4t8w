###############################################################################
# OUTPUTS FILE: outputs.tf
# LOCATION: infrastructure/terraform/modules/storage
#
# DESCRIPTION:
#   This Terraform configuration exposes critical S3 bucket attributes required
#   for seamless integration of media file storage within the Dog Walking
#   Application. Aligns with the following requirements:
#     - Media Storage Integration (Ref: 2. SYSTEM ARCHITECTURE/2.2.1 Core Components/Data Storage Components)
#     - Storage Security (Ref: 7. SECURITY CONSIDERATIONS/7.2 Data Security)
#     - Data Retention (Ref: 8. APPENDICES/8.1.3 Data Retention Schedule)
#
# DEPENDENCIES & REFERENCES:
#   - Primary S3 bucket resource: aws_s3_bucket.media_bucket (imported from main.tf)
#   - Exposing the bucket ID, ARN, and domain name ensures that:
#       1. Other modules and external services can reference the unique ID for
#          operational tasks and lifecycle management (e.g., logging, replication).
#       2. IAM policies can be formed securely using the ARN to correctly
#          identify and grant privileges to this bucket.
#       3. The domain name can be leveraged for constructing secure, direct URLs
#          pointing to media files (images, user uploads, etc.).
#
# USAGE:
#   - The outputs defined in this file will be accessible where this module is
#     called, offering consistent references to the underlying S3 bucket
#     infrastructure. This helps maintain compliance with the system's data
#     retention guidelines, security standards, and real-time media handling
#     requirements for on-demand dog walking services.
###############################################################################


###############################################################################
# OUTPUT: media_bucket_id
# PURPOSE:
#   Exposes the unique identifier (name) of the chosen S3 bucket, which is
#   critical for referencing the bucket in other parts of the infrastructure
#   (e.g., for media file retention processes, or bridging to external modules
#   that require knowledge of the specific bucket name).
#
#   - System Architecture Ref: Ensures modules can retrieve the correct S3
#     resource in line with data storage design.
#   - Security Consideration Ref: Helps define granular IAM policies, ensuring
#     that only the specified bucket is accessible.
#   - Data Retention Ref: Interlinks with lifecycle rules to track which bucket
#     holds media and how it is retained.
###############################################################################
output "media_bucket_id" {
  description = "The unique identifier of the S3 bucket used for storing application media files such as walk photos and user uploads."
  value       = aws_s3_bucket.media_bucket.id
  sensitive   = false
}


###############################################################################
# OUTPUT: media_bucket_arn
# PURPOSE:
#   Exports the Amazon Resource Name (ARN) of the S3 bucket, enabling other
#   Terraform configurations or cross-service integrations to:
#     - Attach IAM policies precisely for read/write/deletion or other advanced
#       operations on the media bucket.
#     - Ensure the correct resource is pinpointed without ambiguity.
#
#   - System Architecture Ref: Relevant for cross-service communication and
#     understanding which S3 resource is used to store sensitive media data.
#   - Security Consideration Ref: Core to the principle of least privilege,
#     allowing us to define exact ARNs in IAM policies.
#   - Data Retention Ref: The ARN is critical when applying or auditing the
#     lifecycle policies affecting stored media.
###############################################################################
output "media_bucket_arn" {
  description = "The Amazon Resource Name (ARN) of the S3 bucket, used for configuring IAM policies and cross-service permissions."
  value       = aws_s3_bucket.media_bucket.arn
  sensitive   = false
}


###############################################################################
# OUTPUT: media_bucket_domain_name
# PURPOSE:
#   Provides the fully-qualified domain name of the media S3 bucket, useful for
#   directly accessing stored files when constructing URLs (e.g., user-uploaded
#   images, walk photos) in the Dog Walking Application:
#     - Facilitates real-time sharing of walk photos between dog owners and
#       walkers, adhering to the system's real-time capabilities.
#     - Integrates with content delivery strategies or direct S3 references to
#       ensure user satisfaction and quick load times.
#
#   - System Architecture Ref: Ensures the application can produce valid S3 URLs
#     for retrieving or uploading media.
#   - Security Consideration Ref: In conjunction with bucket policies, ensures
#     correct usage of the domain to limit unwanted public exposure.
#   - Data Retention Ref: Simplifies referencing older or archived media objects
#     needed for compliance during the retention period before deletion.
###############################################################################
output "media_bucket_domain_name" {
  description = "The fully-qualified domain name of the S3 bucket, used for constructing URLs for media file access."
  value       = aws_s3_bucket.media_bucket.bucket_domain_name
  sensitive   = false
}