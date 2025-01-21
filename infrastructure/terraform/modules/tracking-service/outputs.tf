###############################################################################
# Purpose:
#   This file defines Terraform outputs for the Tracking Service module,
#   exposing critical resource information needed by other parts of the
#   infrastructure. These outputs align with the real-time location tracking
#   requirements described in the technical specifications, ensuring that
#   deployment, discovery, and connection details are readily available for
#   downstream modules or services.
#
# References to Imported Resources (from main.tf):
#   - aws_ecs_cluster.this.id / .name
#   - aws_db_instance.timescaledb.endpoint / .address
#   - aws_mq_broker.mqtt_broker.instances / .security_groups
#
# JSON Specification Requirements:
#   1. cluster_id
#   2. cluster_name
#   3. timescaledb_endpoint
#   4. timescaledb_address
#   5. mqtt_broker_endpoints
#   6. mqtt_broker_security_group_id
###############################################################################

###############################################################################
# OUTPUT: cluster_id
# -----------------------------------------------------------------------------
# Purpose:
#   Exposes the ECS Cluster ID where the Go-based real-time tracking service
#   (with MQTT integration) is deployed. Essential for referencing the cluster
#   in further service definitions, ECS task scheduling, or integration with
#   CI/CD pipelines.
###############################################################################
output "cluster_id" {
  description = "ID of the ECS cluster for the real-time tracking service."
  value       = aws_ecs_cluster.this.id
}

###############################################################################
# OUTPUT: cluster_name
# -----------------------------------------------------------------------------
# Purpose:
#   Exposes the ECS Cluster name to facilitate service discovery, logging
#   integrations, and external referencing for real-time tracking tasks.
#   Useful in monitoring dashboards and environment-specific naming conventions.
###############################################################################
output "cluster_name" {
  description = "Name of the ECS cluster for the real-time tracking service."
  value       = aws_ecs_cluster.this.name
}

###############################################################################
# OUTPUT: timescaledb_endpoint
# -----------------------------------------------------------------------------
# Purpose:
#   Reveals the endpoint for the TimescaleDB instance that stores GPS
#   tracking data and walk timelines. Marked as sensitive to minimize
#   accidental exposure of database connection details in logs.
###############################################################################
output "timescaledb_endpoint" {
  description = "Endpoint (hostname + port) of TimescaleDB for storing GPS data."
  value       = aws_db_instance.timescaledb.endpoint
  sensitive   = true
}

###############################################################################
# OUTPUT: timescaledb_address
# -----------------------------------------------------------------------------
# Purpose:
#   Publishes the DNS address for the TimescaleDB instance, typically used to
#   construct connection strings or DSNs for the real-time tracking microservice.
###############################################################################
output "timescaledb_address" {
  description = "DNS address of the TimescaleDB instance for real-time tracking."
  value       = aws_db_instance.timescaledb.address
}

###############################################################################
# OUTPUT: mqtt_broker_endpoints
# -----------------------------------------------------------------------------
# Purpose:
#   Provides the list of MQTT broker endpoints that the real-time tracking
#   service and connected clients will use to publish/subscribe to location
#   updates. Critical for ensuring that dog walkers and owners have immediate
#   connectivity via the managed ActiveMQ broker.
###############################################################################
output "mqtt_broker_endpoints" {
  description = "List of MQTT broker endpoints for real-time location updates."
  value       = flatten([
    for instance in aws_mq_broker.mqtt_broker.instances : instance.endpoints
  ])
}

###############################################################################
# OUTPUT: mqtt_broker_security_group_id
# -----------------------------------------------------------------------------
# Purpose:
#   Discloses the primary MQTT broker security group ID, enabling additional
#   modules or dependencies to reference or attach rules for secure
#   communications within the private VPC.
###############################################################################
output "mqtt_broker_security_group_id" {
  description = "Security group ID used by the MQTT broker for real-time tracking."
  value       = aws_mq_broker.mqtt_broker.security_groups[0]
}