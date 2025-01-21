###############################################################################
# TERRAFORM CONFIGURATION FOR MULTI-DATABASE INFRASTRUCTURE
# ---------------------------------------------------------------------------
# This file provisions and manages the database tier for the Dog Walking
# Application, including:
#   1. A DB subnet group for RDS and ElastiCache
#   2. Aurora PostgreSQL for user profiles (high availability, multi-AZ)
#   3. MongoDB Atlas cluster for walk records (replica set & backups)
#   4. TimescaleDB on RDS for GPS tracking data (hypertables, large storage)
#   5. Redis ElastiCache replication group for caching (failover, encryption)
#
# References and Requirements:
#  - Technical Specs/2.2.2 Data Storage Components
#    * PostgreSQL, MongoDB, TimescaleDB, Redis
#  - High Availability (Tech Specs/2.5.1, 8.1)
#    * Multi-AZ and replica configurations
#  - Data Storage Strategy (Tech Specs/5.2.2)
#    * Partitioning (hash/time-based), hypertables for time-series
#  - Security Architecture (Tech Specs/7.2)
#    * Encryption at rest & in transit, KMS usage, network isolation
###############################################################################

###############################################################################
# REQUIRED PROVIDERS BLOCK
###############################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0" # AWS provider ~> 4.0
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.0" # MongoDB Atlas provider ~> 1.0
    }
  }
}

###############################################################################
# AWS PROVIDER CONFIGURATION
# - Region is driven by var.region
# - We use default tags to ensure consistent labeling across AWS resources
###############################################################################
provider "aws" {
  region = var.region

  # Optional default tags can unify environment tagging and other cost labels
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "dog-walking"
    }
  }
}

###############################################################################
# MONGODB ATLAS PROVIDER CONFIGURATION
# - Placeholder for public_key / private_key or additional config
# - Adjust to your actual credential retrieval or environment variables
###############################################################################
provider "mongodbatlas" {
  # Example environment variable usage for credentials:
  # public_key  = var.mongodb_public_key
  # private_key = var.mongodb_private_key
  # project_id  = var.mongodb_project_id
}

###############################################################################
# DB SUBNET GROUP
# ---------------------------------------------------------------------------
# Subnet group used by RDS (Aurora PostgreSQL, TimescaleDB) and ElastiCache.
# Ensures databases are placed in the specified private subnets for security.
#
# Exported Attributes Needed:
#   • aws_db_subnet_group.main.id
#   • aws_db_subnet_group.main.arn
###############################################################################
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.subnet_ids

  description = "Subnet group for RDS/ElastiCache in the ${var.environment} environment."

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
    Module      = "database"
    Tier        = "data"
  }
}

###############################################################################
# AURORA POSTGRESQL (USER PROFILES)
# ---------------------------------------------------------------------------
# This section provisions the Aurora cluster used primarily for user profiles,
# authentication data, and other relational records. It enables:
#   • Multi-AZ by creating multiple cluster instances
#   • Encryption at rest via KMS
#   • Automated backups and retention
#   • Performance insights and monitoring
#
# Resource (Cluster):
#   aws_rds_cluster.aurora_postgres
#
# Resource (Instances):
#   aws_rds_cluster_instance.aurora_instances
#
# Exported Attributes Needed:
#   • endpoint
#   • reader_endpoint
#   • cluster_identifier
###############################################################################

# Primary Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "aurora_postgres" {
  cluster_identifier = "${var.environment}-aurora-postgres-cluster"
  engine            = "aurora-postgresql"
  # Example engine version: "13.7", "14.6", etc., pinned as needed
  engine_version    = "13.7"

  # Database name can be used as default, or left out if managed externally
  database_name = "user_profiles"

  # REPLICATION & SECURITY
  storage_encrypted  = var.enable_encryption
  kms_key_id         = var.kms_key_arn

  # BACKUP & RETENTION
  backup_retention_period = var.postgres_backup_retention_period
  preferred_backup_window = var.backup_window

  # MAINTENANCE
  db_subnet_group_name       = aws_db_subnet_group.main.name
  preferred_maintenance_window = var.maintenance_window
  deletion_protection        = var.deletion_protection
  copy_tags_to_snapshot      = true

  # MONITORING & INSIGHTS
  performance_insights_enabled = var.enable_performance_insights
  performance_insights_kms_key_id = var.kms_key_arn
  # If Enhanced Monitoring is desired at the cluster layer, typically it's set
  # at the instance level. Some settings can propagate down from cluster.

  # TAGGING
  tags = {
    Name                 = "${var.environment}-aurora-postgres-cluster"
    Environment          = var.environment
    Module               = "database"
    DatabaseType         = "AuroraPostgreSQL"
    Encryption           = var.enable_encryption ? "enabled" : "disabled"
    PerformanceInsights  = var.enable_performance_insights ? "enabled" : "disabled"
  }
}

# Aurora PostgreSQL Instances (Multi-AZ for High Availability)
resource "aws_rds_cluster_instance" "aurora_instances" {
  # Creating two instances if multi_az is true, else one. Adjust as needed.
  count = var.postgres_multi_az ? 2 : 1

  identifier        = "${var.environment}-aurora-postgres-${count.index}"
  cluster_identifier = aws_rds_cluster.aurora_postgres.id
  engine           = aws_rds_cluster.aurora_postgres.engine
  instance_class   = var.postgres_instance_class

  # MONITORING
  monitoring_interval           = var.enable_enhanced_monitoring ? var.monitoring_interval : 0
  performance_insights_enabled  = var.enable_performance_insights
  performance_insights_kms_key_id = var.kms_key_arn

  # Each instance is placed in a different AZ automatically if possible
  db_subnet_group_name = aws_db_subnet_group.main.name
  promotion_tier       = count.index + 1

  # Apply changes immediately or wait for the next maintenance window
  apply_immediately = true

  # TAGS
  tags = {
    Name          = "${var.environment}-aurora-postgres-instance-${count.index}"
    Environment   = var.environment
    Module        = "database"
    DBType        = "AuroraPostgreSQL"
    MultiAZ       = var.postgres_multi_az ? "true" : "false"
  }
}

###############################################################################
# TIMESCALEDB (GPS TRACKING DATA)
# ---------------------------------------------------------------------------
# TimescaleDB is an extension of PostgreSQL optimized for time-series data:
#   • Store large-scale GPS location logs
#   • Hypertables to manage time-based partitions
#   • High ingestion throughput
#
# Resource (Cluster):
#   aws_rds_cluster.timescaledb
#
# Resource (Instances):
#   aws_rds_cluster_instance.timescale_instances
#
# Exported Attributes Needed:
#   • endpoint
#   • cluster_identifier
###############################################################################

# OPTIONAL: Parameter group to enable Timescale extension
resource "aws_db_parameter_group" "timescale" {
  name        = "${var.environment}-timescale-parameter-group"
  family      = "postgres14" 
  description = "Parameter group for TimescaleDB in ${var.environment}"

  # Shared preload libraries for timescaledb, necessary for extension usage
  parameter {
    name  = "shared_preload_libraries"
    value = "timescaledb"
  }

  tags = {
    Name        = "${var.environment}-timescale-parameter-group"
    Environment = var.environment
    Module      = "database"
  }
}

# RDS Cluster for Timescale
resource "aws_rds_cluster" "timescaledb" {
  cluster_identifier = "${var.environment}-timescaledb-cluster"
  engine            = "postgres"
  # Example version known to be compatible with Timescale. Adjust if needed.
  engine_version    = "14.6"

  database_name = "gps_tracking"

  # Parameter group holds timescale extension, assigned at cluster level
  db_parameter_group_name = aws_db_parameter_group.timescale.name

  storage_encrypted  = var.enable_encryption
  kms_key_id         = var.kms_key_arn

  backup_retention_period   = var.timescaledb_backup_retention_period
  preferred_backup_window   = var.backup_window
  preferred_maintenance_window = var.maintenance_window
  deletion_protection       = var.deletion_protection
  copy_tags_to_snapshot     = true

  db_subnet_group_name = aws_db_subnet_group.main.name

  # Monitoring
  performance_insights_enabled  = var.enable_performance_insights
  performance_insights_kms_key_id = var.kms_key_arn

  tags = {
    Name                 = "${var.environment}-timescaledb-cluster"
    Environment          = var.environment
    Module               = "database"
    DatabaseType         = "TimescaleDB"
    Encryption           = var.enable_encryption ? "enabled" : "disabled"
    PerformanceInsights  = var.enable_performance_insights ? "enabled" : "disabled"
  }
}

# TimescaleDB Instances (similar approach to Aurora for Multi-AZ)
resource "aws_rds_cluster_instance" "timescale_instances" {
  count              = var.postgres_multi_az ? 2 : 1
  identifier         = "${var.environment}-timescaledb-instance-${count.index}"
  cluster_identifier = aws_rds_cluster.timescaledb.id
  engine             = aws_rds_cluster.timescaledb.engine
  instance_class     = var.timescaledb_instance_class

  db_subnet_group_name = aws_db_subnet_group.main.name
  monitoring_interval  = var.enable_enhanced_monitoring ? var.monitoring_interval : 0

  performance_insights_enabled  = var.enable_performance_insights
  performance_insights_kms_key_id = var.kms_key_arn
  apply_immediately             = true

  tags = {
    Name        = "${var.environment}-timescaledb-instance-${count.index}"
    Environment = var.environment
    Module      = "database"
    DBType      = "TimescaleDB"
  }
}

###############################################################################
# MONGODB ATLAS CLUSTER (WALK RECORDS)
# ---------------------------------------------------------------------------
# This section configures MongoDB Atlas via the mongodbatlas provider. The
# cluster is used to store booking records, ephemeral data for walk scheduling,
# and scaled out with replica sets and optional sharding.
#
# Exported Attributes Needed:
#   • connection_strings
#   • cluster_id
###############################################################################
resource "mongodbatlas_cluster" "main" {
  # Adjust cluster name, project_id, replication specs, backups as needed
  name       = "${var.environment}-mongo-cluster"
  project_id = var.mongodb_project_id

  # If we want a major_version like "6.0" or "5.0":
  version_release_system = "LTS"
  pit_enabled            = true
  backup_enabled         = true
  provider_name          = "AWS"
  provider_region_name   = var.region
  provider_instance_size_name = var.mongodb_instance_type
  provider_disk_type_name = "STANDARD"

  replication_specs {
    region_name = var.region
    num_shards  = var.mongodb_sharding_enabled ? 2 : 1

    # Each region_config describes a replica set
    region_config {
      analytics_auto_scaling_disk_gb_enabled = true
      electable_specs {
        instance_size  = var.mongodb_instance_type
        node_count     = var.mongodb_replica_count
      }
    }
  }

  # Backup retention
  # As of mongodbatlas, we set a general snapshot schedule or rely on advanced ops
  auto_scaling_disk_gb_enabled = true

  # Tags for MongoDB Atlas (atlas uses labels)
  labels {
    key   = "Environment"
    value = var.environment
  }
  labels {
    key   = "Project"
    value = "dog-walking"
  }

  lifecycle {
    ignore_changes = [
      replication_specs[0].region_config[0].auto_scaling_compute_enabled,
      replication_specs[0].region_config[0].auto_scaling_compute_scale_down_enabled,
    ]
  }
}

###############################################################################
# REDIS ELASTICACHE (CACHING LAYER)
# ---------------------------------------------------------------------------
# High availability and in-memory caching for quick retrieval of frequently
# accessed data (session data, ephemeral location states). This is a replication
# group with at least 2 nodes to mitigate single-node failures.
#
# Exported Attributes Needed:
#   • primary_endpoint_address
#   • reader_endpoint_address
#   • replication_group_id
###############################################################################
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id          = "${var.environment}-redis-repl-group"
  replication_group_description = "Redis replication for caching in ${var.environment}"
  engine                        = "redis"
  engine_version                = "7.0" # or align with your desired version

  # Multi-AZ / high availability
  multi_az_enabled       = true
  automatic_failover_enabled = true
  num_node_groups        = 1
  replicas_per_node_group = 1

  # Subnet group
  subnet_group_name = aws_elasticache_subnet_group.main.name

  # Encryption settings
  at_rest_encryption_enabled      = var.enable_encryption
  transit_encryption_enabled      = true
  kms_key_id                      = var.kms_key_arn
  auth_token                      = random_password.redis_auth.result

  # Maintenance / snapshots
  snapshot_retention_limit        = var.backup_retention_period
  snapshot_window                 = var.backup_window
  preferred_maintenance_window    = var.maintenance_window

  # Security groups might be set externally. Use default if not specified:
  security_group_ids = []

  # TAGS
  tags = {
    Name         = "${var.environment}-redis-repl-group"
    Environment  = var.environment
    Module       = "database"
    Engine       = "redis"
    Encryption   = var.enable_encryption ? "enabled" : "disabled"
  }

  depends_on = [aws_db_subnet_group.main]
}

###############################################################################
# ELASTICACHE SUBNET GROUP FOR REDIS
# - Similar to RDS subnet group, specialized for ElastiCache usage
###############################################################################
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.environment}-elasticache-subnet-group"
  description = "Subnet group for ElastiCache in the ${var.environment} environment"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${var.environment}-elasticache-subnet-group"
    Environment = var.environment
    Module      = "database"
  }
}

###############################################################################
# RANDOM PASSWORD FOR REDIS AUTH (OPTIONAL)
# - Illustrative only, ensure secure handling in production (Vault, Secrets Mgr)
###############################################################################
resource "random_password" "redis_auth" {
  length  = 16
  special = true
}

###############################################################################
# OUTPUTS
# ---------------------------------------------------------------------------
# The JSON specification requires the following named exports. We create
# separate output blocks providing the id/arn or relevant connection strings.
###############################################################################

###############################################################################
# DB SUBNET GROUP
###############################################################################
output "aws_db_subnet_group_id" {
  description = "ID of the DB subnet group used by RDS/ElastiCache"
  value       = aws_db_subnet_group.main.id
}

output "aws_db_subnet_group_arn" {
  description = "ARN of the DB subnet group used by RDS/ElastiCache"
  value       = aws_db_subnet_group.main.arn
}

###############################################################################
# AURORA POSTGRESQL (USER PROFILES)
###############################################################################
output "aws_rds_cluster_endpoint" {
  description = "Primary endpoint for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.aurora_postgres.endpoint
}

output "aws_rds_cluster_reader_endpoint" {
  description = "Reader endpoint for the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.aurora_postgres.reader_endpoint
}

output "aws_rds_cluster_identifier" {
  description = "Identifier of the Aurora PostgreSQL cluster"
  value       = aws_rds_cluster.aurora_postgres.cluster_identifier
}

###############################################################################
# MONGODB ATLAS (WALK RECORDS)
###############################################################################
output "mongodbatlas_cluster_connection_strings" {
  description = "Connection strings for the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.connection_strings
}

output "mongodbatlas_cluster_id" {
  description = "ID of the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.main.cluster_id
}

###############################################################################
# TIMESCALEDB (GPS TRACKING)
###############################################################################
output "aws_rds_cluster_timescaledb_endpoint" {
  description = "Primary endpoint for the TimescaleDB cluster"
  value       = aws_rds_cluster.timescaledb.endpoint
}

output "aws_rds_cluster_timescaledb_identifier" {
  description = "Identifier of the TimescaleDB cluster"
  value       = aws_rds_cluster.timescaledb.cluster_identifier
}

###############################################################################
# REDIS ELASTICACHE (CACHING LAYER)
###############################################################################
output "aws_elasticache_redis_primary_endpoint_address" {
  description = "Primary endpoint address of the Redis replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "aws_elasticache_redis_reader_endpoint_address" {
  description = "Reader endpoint address for read replicas in the Redis replication group"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "aws_elasticache_redis_replication_group_id" {
  description = "Replication group ID for the Redis cluster"
  value       = aws_elasticache_replication_group.redis.replication_group_id
}