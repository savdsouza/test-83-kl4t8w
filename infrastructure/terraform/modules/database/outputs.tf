###############################################################################
# Terrafrom Outputs Configuration for Multi-Database Infrastructure
# ---------------------------------------------------------------------------
# This file exposes key endpoints and connection strings for the Dog Walking
# Application's database layer, including:
#
#  1. PostgreSQL (Aurora) primary and reader endpoints
#  2. MongoDB Atlas connection string
#  3. TimescaleDB endpoint for GPS tracking data
#  4. Redis primary endpoint for caching
#  5. A referenced database Security Group ID
#
# References & Technical Compliance:
# • Technical Specs/2.2.2 Data Storage Components:
#   - Output PostgreSQL, MongoDB, TimescaleDB & Redis details
# • Technical Specs/2.5.1 Infrastructure Requirements:
#   - Provide multi-AZ aware endpoints for read/write flows
# • Security Architecture:
#   - Output of a security group ID controlling DB-level ingress
#
# Implementation Details:
# - The resources referenced here (aws_rds_cluster, mongodbatlas_cluster,
#   aws_elasticache_replication_group) are declared in main.tf.
# - The TimescaleDB cluster is also provisioned in main.tf with a distinct RDS
#   cluster (aws_rds_cluster.timescaledb).
# - For MongoDB Atlas, we handle connection_strings as a list, joined to form
#   a single secure URI output for use in upstream modules.
# - The security_group_id output references the primary security group for
#   database resources. Since no explicit resource exists in this module for
#   DB security groups, we derive the first ID from the ElastiCache replication
#   group’s security_group_ids array, which is typically externally supplied.
###############################################################################


###############################################################################
# 1) postgresql_endpoint
#    Purpose:
#      Primary write endpoint for PostgreSQL Aurora cluster hosting user
#      profiles and authentication data. This endpoint is typically used
#      for read/write transactions and operational queries.
###############################################################################
output "postgresql_endpoint" {
  description = "Primary write endpoint for PostgreSQL Aurora cluster with user profiles and authentication data"
  value       = aws_rds_cluster.aurora_postgres.endpoint
}


###############################################################################
# 2) postgresql_reader_endpoint
#    Purpose:
#      Read-only endpoint for the Aurora cluster to support horizontal scaling
#      of read workloads (e.g., analytics, reporting). This helps offload read
#      queries from the primary DB instance.
###############################################################################
output "postgresql_reader_endpoint" {
  description = "Read-only endpoint for PostgreSQL Aurora cluster to support read scaling"
  value       = aws_rds_cluster.aurora_postgres.reader_endpoint
}


###############################################################################
# 3) mongodb_connection_string
#    Purpose:
#      Secure connection string for the MongoDB Atlas cluster, used to store
#      walk records, booking data, and document-based structures. We join any
#      returned connection strings into a single comma-delimited string.
###############################################################################
output "mongodb_connection_string" {
  description = "Secure connection string for MongoDB Atlas cluster storing walk records and bookings"
  value       = join(",", mongodbatlas_cluster.main.connection_strings)
}


###############################################################################
# 4) timescaledb_endpoint
#    Purpose:
#      Endpoint for the TimescaleDB cluster (built on PostgreSQL) optimized
#      for time-series storage of GPS tracking data. This is used by services
#      handling geolocation events and route analytics.
###############################################################################
output "timescaledb_endpoint" {
  description = "Endpoint for TimescaleDB cluster optimized for GPS tracking data storage"
  value       = aws_rds_cluster.timescaledb.endpoint
}


###############################################################################
# 5) redis_primary_endpoint
#    Purpose:
#      Primary endpoint for the Redis replication group, offering caching
#      and real-time data operations. This references the multi-AZ enabled
#      ElastiCache replication group for high availability.
###############################################################################
output "redis_primary_endpoint" {
  description = "Primary endpoint for Redis replication group used for caching and real-time data"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}


###############################################################################
# 6) security_group_id
#    Purpose:
#      Security group ID controlling access to database resources. In this
#      module, we derive the first security group ID from the Redis
#      replication group if provided. Modify or replace with a dedicated DB
#      security group reference as appropriate for your environment.
###############################################################################
output "security_group_id" {
  description = "Security group ID controlling access to database resources"
  value = length(aws_elasticache_replication_group.redis.security_group_ids) > 0 ?
    element(aws_elasticache_replication_group.redis.security_group_ids, 0) :
    ""
}