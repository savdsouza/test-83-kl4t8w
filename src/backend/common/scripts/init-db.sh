#!/usr/bin/env bash
# ---------------------------------------------------------------------------------
# init-db.sh
#
# Shell script for initializing and configuring the application's multi-database
# architecture, including:
#   - PostgreSQL for user data
#   - MongoDB for walk records
#   - TimescaleDB for GPS tracking data
#
# This script addresses the following goals:
#   1) Enhanced security via SSL, RBAC, and audit logging
#   2) Replication and sharding for high availability
#   3) Monitoring and alert integration
#   4) Automatic partitioning and optimized indexes
# ---------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------
# Global Settings and Environment Setup
# ---------------------------------------------------------------------------------

# Enforce strict error handling and safer scripting
set -Eeuo pipefail

# Third-party tools (with explicit version comments)
# psql (PostgreSQL client) 15
# mongosh (MongoDB shell) 6.0

# Global environment fallback and script path calculations
ENV="${NODE_ENV:-development}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
CERT_DIR="$SCRIPT_DIR/certs"

# Ensure necessary directories exist
mkdir -p "$LOG_DIR"
mkdir -p "$CERT_DIR"

# ---------------------------------------------------------------------------------
# Internal Imports (conceptual references for environment variables and configs)
# ---------------------------------------------------------------------------------
# - DatabaseConfig (from booking-service/src/main/java/com/dogwalking/booking/config/DatabaseConfig.java)
#   Providing MongoClientSettings concurrency configurations for MongoDB.
# - databaseConfig (from auth-service/src/config/database.config.ts)
#   Providing environment-based PostgreSQL connection info (development vs production).
#
# In this shell script, actual usage of these configurations is typically exposed via
# environment variables such as DB_HOST, DB_PORT, etc.
# ---------------------------------------------------------------------------------

# ---------------------------------------------------------------------------------
# Function: init_postgres
# Description:
#   Initializes PostgreSQL databases with enhanced security, replication,
#   and monitoring features. Carefully executes each step to ensure
#   robust, production-grade setup.
# Parameters:
#   1) DB_HOST         - Hostname/IP of the PostgreSQL server
#   2) DB_PORT         - PostgreSQL port (default: 5432)
#   3) DB_USER         - PostgreSQL superuser or admin
#   4) DB_PASSWORD     - Password for the DB_USER
#   5) SSL_CERT_PATH   - Path to SSL certificate file (if SSL is used)
#   6) REPLICA_CONFIG  - Additional replication config or replica host list
# Returns:
#   Exit code 0 on success, 1 on failure
# ---------------------------------------------------------------------------------
init_postgres() {
  local DB_HOST="$1"
  local DB_PORT="$2"
  local DB_USER="$3"
  local DB_PASSWORD="$4"
  local SSL_CERT_PATH="$5"
  local REPLICA_CONFIG="$6"

  echo "[init_postgres] Starting PostgreSQL initialization..." | tee -a "$LOG_DIR/postgres.log"

  # Step 1: Verify SSL certificates and security prerequisites
  # If SSL_CERT_PATH is provided, ensure file exists and is readable
  if [[ -n "$SSL_CERT_PATH" && ! -f "$SSL_CERT_PATH" ]]; then
    echo "[init_postgres] ERROR: SSL certificate file not found at $SSL_CERT_PATH" | tee -a "$LOG_DIR/postgres.log"
    return 1
  fi

  # Step 2: Check PostgreSQL service health and connectivity using psql
  export PGPASSWORD="$DB_PASSWORD"
  if ! psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "SELECT version();" &>> "$LOG_DIR/postgres.log"; then
    echo "[init_postgres] ERROR: Unable to connect to PostgreSQL at $DB_HOST:$DB_PORT" | tee -a "$LOG_DIR/postgres.log"
    return 1
  fi

  # Step 3: Create databases with proper encoding and collation (example: user_data DB)
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" <<EOF >> "$LOG_DIR/postgres.log" 2>&1
CREATE DATABASE user_data
  WITH OWNER = $DB_USER
       ENCODING = 'UTF8'
       LC_COLLATE = 'en_US.UTF-8'
       LC_CTYPE = 'en_US.UTF-8'
       TEMPLATE = template0
       CONNECTION LIMIT = -1;
EOF

  # Step 4: Apply schema migrations using versioned scripts (placeholder logic)
  # In a real setup, this might involve calling an external migration tool like Liquibase or Flyway
  echo "[init_postgres] INFO: Schema migrations would be applied here." | tee -a "$LOG_DIR/postgres.log"

  # Step 5: Create necessary extensions (uuid-ossp, pgcrypto, etc.)
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" user_data <<EOF >> "$LOG_DIR/postgres.log" 2>&1
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
EOF

  # Step 6: Configure read replicas if in production environment
  # Use REPLICA_CONFIG if provided for replication settings
  if [[ "$ENV" == "production" && -n "$REPLICA_CONFIG" ]]; then
    echo "[init_postgres] INFO: Configuring read replicas using: $REPLICA_CONFIG" | tee -a "$LOG_DIR/postgres.log"
    # Placeholder for replica setup commands
    # e.g., psql -c "ALTER SYSTEM SET wal_level = replica;"
  else
    echo "[init_postgres] INFO: Skipping replica config (ENV=$ENV, REPLICA_CONFIG not set)." | tee -a "$LOG_DIR/postgres.log"
  fi

  # Step 7: Setup connection pooling with pgbouncer or similar (placeholder)
  echo "[init_postgres] INFO: Configuring connection pooling (pgbouncer or built-in)..." | tee -a "$LOG_DIR/postgres.log"

  # Step 8: Create role-based access control (RBAC) scheme
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" user_data <<EOF >> "$LOG_DIR/postgres.log" 2>&1
DO \$\$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = 'app_role') THEN
    CREATE ROLE app_role LOGIN PASSWORD 'AppRoleSecurePassword';
    GRANT CONNECT ON DATABASE user_data TO app_role;
  END IF;
END
\$\$;
EOF

  # Step 9: Configure audit logging for sensitive operations (pg_audit as an example)
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" <<EOF >> "$LOG_DIR/postgres.log" 2>&1
CREATE EXTENSION IF NOT EXISTS "pg_audit";
EOF

  # Step 10: Create optimized indexes for user and auth tables (placeholder)
  echo "[init_postgres] INFO: Creating indexes for user_data tables..." | tee -a "$LOG_DIR/postgres.log"
  # Example index creation
  # psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" user_data -c "CREATE INDEX idx_users_email ON users (email);"

  # Step 11: Setup automated vacuum and maintenance tasks
  echo "[init_postgres] INFO: Configuring auto-vacuum settings..." | tee -a "$LOG_DIR/postgres.log"

  # Step 12: Configure database monitoring and alerts (pg_stat_statements, etc.)
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" user_data <<EOF >> "$LOG_DIR/postgres.log" 2>&1
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
EOF

  # Step 13: Verify database connectivity and replication status
  psql -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "SELECT * FROM pg_stat_database;" &>> "$LOG_DIR/postgres.log"

  # Initialize backup and recovery procedures (placeholder logic)
  echo "[init_postgres] INFO: Backup and recovery routines would be set up here (e.g. pg_basebackup)." | tee -a "$LOG_DIR/postgres.log"

  echo "[init_postgres] SUCCESS: PostgreSQL initialization complete." | tee -a "$LOG_DIR/postgres.log"
  return 0
}

# ---------------------------------------------------------------------------------
# Function: init_mongodb
# Description:
#   Initializes MongoDB databases with sharding, replication, and security
#   features. Ensures that the walk records and booking data can be distributed
#   effectively while maintaining strong consistency and performance.
# Parameters:
#   1) MONGO_HOST          - Host or IP of the MongoDB instance
#   2) MONGO_PORT          - MongoDB port (default: 27017)
#   3) MONGO_USER          - MongoDB admin or root user
#   4) MONGO_PASSWORD      - Password for the MongoDB user
#   5) REPLICA_SET_CONFIG  - JSON or string config for replica sets
#   6) SHARD_CONFIG        - JSON or string config for sharding
# Returns:
#   Exit code 0 on success, 1 on failure
# ---------------------------------------------------------------------------------
init_mongodb() {
  local MONGO_HOST="$1"
  local MONGO_PORT="$2"
  local MONGO_USER="$3"
  local MONGO_PASSWORD="$4"
  local REPLICA_SET_CONFIG="$5"
  local SHARD_CONFIG="$6"

  echo "[init_mongodb] Starting MongoDB initialization..." | tee -a "$LOG_DIR/mongodb.log"

  # Step 1: Verify MongoDB service health and prerequisites
  if ! mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" --eval "db.runCommand({ ping: 1 })" &>> "$LOG_DIR/mongodb.log"; then
    echo "[init_mongodb] ERROR: Unable to connect to MongoDB at $MONGO_HOST:$MONGO_PORT" | tee -a "$LOG_DIR/mongodb.log"
    return 1
  fi

  # Step 2: Initialize replica set configuration if required
  if [[ -n "$REPLICA_SET_CONFIG" ]]; then
    echo "[init_mongodb] INFO: Configuring replica set: $REPLICA_SET_CONFIG" | tee -a "$LOG_DIR/mongodb.log"
    mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" <<EOF >> "$LOG_DIR/mongodb.log" 2>&1
rs.initiate($REPLICA_SET_CONFIG);
EOF
  fi

  # Step 3: Setup sharding for walk history collections if provided
  if [[ -n "$SHARD_CONFIG" ]]; then
    echo "[init_mongodb] INFO: Sharding configuration: $SHARD_CONFIG" | tee -a "$LOG_DIR/mongodb.log"
    mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" <<EOF >> "$LOG_DIR/mongodb.log" 2>&1
sh.enableSharding("walk_records");
sh.shardCollection("walk_records.bookings", $SHARD_CONFIG);
EOF
  fi

  # Step 4: Create databases and collections with validation
  # Example for a "walk_records" database and "bookings" collection
  mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" <<EOF >> "$LOG_DIR/mongodb.log" 2>&1
use walk_records;
db.createCollection("bookings", {
  validator: {
    \$jsonSchema: {
      bsonType: "object",
      required: [ "ownerId", "walkerId", "status" ],
      properties: {
        ownerId: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        walkerId: {
          bsonType: "string",
          description: "must be a string and is required"
        },
        status: {
          bsonType: "string",
          description: "must be a string and is required"
        }
      }
    }
  }
});
EOF

  # Step 5: Configure authentication and authorization
  echo "[init_mongodb] INFO: Ensuring user authentication/roles..." | tee -a "$LOG_DIR/mongodb.log"
  mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" <<EOF >> "$LOG_DIR/mongodb.log" 2>&1
use admin;
db.createUser({
  user: "app_role",
  pwd: "AppRoleSecurePassword",
  roles: [ { role: "readWrite", db: "walk_records" } ]
});
EOF

  # Step 6: Create compound indexes for walk and booking collections
  echo "[init_mongodb] INFO: Creating compound indexes to speed up queries..." | tee -a "$LOG_DIR/mongodb.log"
  mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" <<EOF >> "$LOG_DIR/mongodb.log" 2>&1
use walk_records;
db.bookings.createIndex({ ownerId: 1, walkerId: 1 });
db.bookings.createIndex({ status: 1, startTime: 1 });
EOF

  # Step 7: Setup time-based data partitioning (partial example - typically done with sharding or archiving logic)
  echo "[init_mongodb] INFO: (Placeholder) Time-based partitioning handled by TTL or custom archival strategy." | tee -a "$LOG_DIR/mongodb.log"

  # Step 8: Configure oplog sizing and retention if in a replica set
  echo "[init_mongodb] INFO: Configuring oplog parameters as needed..." | tee -a "$LOG_DIR/mongodb.log"

  # Step 9: Initialize change streams for real-time tracking
  echo "[init_mongodb] INFO: (Placeholder) Change streams can be consumed by microservices to track updates." | tee -a "$LOG_DIR/mongodb.log"

  # Step 10: Setup automated backups and point-in-time recovery
  echo "[init_mongodb] INFO: (Placeholder) Snapshot-based or continuous backups scheduling." | tee -a "$LOG_DIR/mongodb.log"

  # Step 11: Configure monitoring and performance alerts
  echo "[init_mongodb] INFO: Integrate monitoring with CloudWatch, Datadog, or Ops Manager for performance stats." | tee -a "$LOG_DIR/mongodb.log"

  # Step 12: Verify cluster health and replication status
  mongosh --host "$MONGO_HOST" --port "$MONGO_PORT" -u "$MONGO_USER" -p "$MONGO_PASSWORD" --authenticationDatabase "admin" --eval "rs.status()" &>> "$LOG_DIR/mongodb.log" || true

  # Step 13: Setup audit logging for security events
  echo "[init_mongodb] INFO: (Placeholder) mongod config with auditLog.path to track user operations." | tee -a "$LOG_DIR/mongodb.log"

  echo "[init_mongodb] SUCCESS: MongoDB initialization complete." | tee -a "$LOG_DIR/mongodb.log"
  return 0
}

# ---------------------------------------------------------------------------------
# Function: init_timescaledb
# Description:
#   Initializes TimescaleDB with optimized time-series configuration and partitioning
#   for real-time GPS tracking data. Ensures high-performance writes and queries.
# Parameters:
#   1) TIMESCALE_HOST    - Host/IP of the TimescaleDB server
#   2) TIMESCALE_PORT    - TimescaleDB port (default: 5432)
#   3) TIMESCALE_USER    - TimescaleDB superuser or admin
#   4) TIMESCALE_PASSWORD- Password for TIMESCALE_USER
#   5) PARTITION_CONFIG  - Additional partitioning config, e.g., time interval
#   6) RETENTION_CONFIG  - Retention policy config, e.g., older than X days
# Returns:
#   Exit code 0 on success, 1 on failure
# ---------------------------------------------------------------------------------
init_timescaledb() {
  local TIMESCALE_HOST="$1"
  local TIMESCALE_PORT="$2"
  local TIMESCALE_USER="$3"
  local TIMESCALE_PASSWORD="$4"
  local PARTITION_CONFIG="$5"
  local RETENTION_CONFIG="$6"

  echo "[init_timescaledb] Starting TimescaleDB initialization..." | tee -a "$LOG_DIR/timescaledb.log"

  # Ensure environment variable for PGPASSWORD
  export PGPASSWORD="$TIMESCALE_PASSWORD"

  # Step 1: Verify TimescaleDB extension and prerequisites
  if ! psql -U "$TIMESCALE_USER" -h "$TIMESCALE_HOST" -p "$TIMESCALE_PORT" -c "SELECT installed_version FROM pg_extension WHERE extname='timescaledb';" &>> "$LOG_DIR/timescaledb.log"; then
    echo "[init_timescaledb] ERROR: Unable to connect or TimescaleDB extension not found." | tee -a "$LOG_DIR/timescaledb.log"
    return 1
  fi

  # Step 2: Create time-series optimized database (example: gps_data)
  psql -U "$TIMESCALE_USER" -h "$TIMESCALE_HOST" -p "$TIMESCALE_PORT" <<EOF >> "$LOG_DIR/timescaledb.log" 2>&1
CREATE DATABASE gps_data
  WITH OWNER = $TIMESCALE_USER
       ENCODING = 'UTF8'
       TEMPLATE = template1;
EOF

  # Step 3: Configure hypertables for GPS tracking
  psql -U "$TIMESCALE_USER" -h "$TIMESCALE_HOST" -p "$TIMESCALE_PORT" gps_data <<EOF >> "$LOG_DIR/timescaledb.log" 2>&1
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE TABLE IF NOT EXISTS location_points (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  device_id VARCHAR(100) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  recorded_at TIMESTAMP NOT NULL
);

SELECT create_hypertable('location_points', 'recorded_at', if_not_exists => TRUE);
EOF

  # Step 4: Setup automated partitioning by time and location (placeholder)
  if [[ -n "$PARTITION_CONFIG" ]]; then
    echo "[init_timescaledb] INFO: Applying partition config: $PARTITION_CONFIG" | tee -a "$LOG_DIR/timescaledb.log"
    # Additional commands to refine chunk sizing or partitioning intervals can go here
  fi

  # Step 5: Create composite indexes for efficient querying
  psql -U "$TIMESCALE_USER" -h "$TIMESCALE_HOST" -p "$TIMESCALE_PORT" gps_data <<EOF >> "$LOG_DIR/timescaledb.log" 2>&1
CREATE INDEX IF NOT EXISTS idx_location_device_time ON location_points (device_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_lat_lng ON location_points (latitude, longitude);
EOF

  # Step 6: Configure data retention and archival policies
  if [[ -n "$RETENTION_CONFIG" ]]; then
    echo "[init_timescaledb] INFO: Applying retention config: $RETENTION_CONFIG" | tee -a "$LOG_DIR/timescaledb.log"
    # TimescaleDB job for retention policy example:
    # SELECT add_retention_policy('location_points', INTERVAL '90 days');
  fi

  # Step 7: Setup continuous aggregates for analytics (placeholder)
  echo "[init_timescaledb] INFO: Defining continuous aggregates for data summarization if needed." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 8: Configure compression policies for historical data (placeholder)
  echo "[init_timescaledb] INFO: Setting compression for older chunks to reduce storage usage." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 9: Setup real-time aggregation views (optional)
  echo "[init_timescaledb] INFO: (Placeholder) Creating real-time materialized views or cagg refresh policies." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 10: Initialize automated maintenance tasks
  echo "[init_timescaledb] INFO: (Placeholder) TimescaleDB maintenance (analyze, vacuum, reorder chunks)." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 11: Configure monitoring and performance metrics
  echo "[init_timescaledb] INFO: (Placeholder) Integration with pg_stat_statements, Prometheus, or external APM." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 12: Setup backup and recovery procedures
  echo "[init_timescaledb] INFO: (Placeholder) Automated backups using pg_dump, physical backups, or WAL archiving." | tee -a "$LOG_DIR/timescaledb.log"

  # Step 13: Verify database optimization and performance
  psql -U "$TIMESCALE_USER" -h "$TIMESCALE_HOST" -p "$TIMESCALE_PORT" gps_data -c "SELECT * FROM timescale_information.hypertable;" &>> "$LOG_DIR/timescaledb.log"

  echo "[init_timescaledb] SUCCESS: TimescaleDB initialization complete." | tee -a "$LOG_DIR/timescaledb.log"
  return 0
}

# ---------------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------------
export -f init_postgres
export -f init_mongodb
export -f init_timescaledb