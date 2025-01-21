###############################################################################
# Root Terraform outputs for the Dog Walking Platform's Tracking Service.
# This file centralizes and exposes essential infrastructure outputs from
# the tracking service modules to enable multi-region deployment, high
# availability, and seamless integration with other system components.
#
# Each output includes a detailed description, a reference to the underlying
# module output, and a sensitivity setting to secure sensitive information
# such as database credentials. These outputs facilitate the integration
# between multiple layers of the Dog Walking Platform, ensuring real-time
# location tracking, scalable data management, and robust global deployment.
###############################################################################


###############################
# TRACKING SERVICE MQTT ENDPOINTS
###############################
# Description:
#   - A globally distributed list of MQTT broker endpoints that power the
#     real-time location tracking functionality. Each endpoint is a fully
#     qualified domain name paired with a port number for secure communication.
#   - These endpoints are used by both mobile and backend services to
#     publish and subscribe to live GPS updates, geofencing events, and
#     other asynchronous messages across multiple regions, ensuring
#     ultra-low latency and highly available tracking.
#
# Usage:
#   - Reference this output from other Terraform configurations or modules
#     by using "module.<module_name>.tracking_service_mqtt_endpoints".
#   - Primarily consumed by environment-specific Terraform stacks and
#     configuration management systems that need to distribute real-time
#     communication settings to application services.
#
output "tracking_service_mqtt_endpoints" {
  description = "List of MQTT broker endpoints for real-time location tracking across regions. Format: list of fully qualified domain names with port numbers."
  value       = "${module.tracking_service.mqtt_broker_endpoints}"
  sensitive   = false
}


###############################
# TRACKING SERVICE DATABASE ENDPOINT
###############################
# Description:
#   - A primary TimescaleDB endpoint used for storing, indexing, and retrieving
#     high-volume GPS data points in near real-time for the Dog Walking
#     Platform. Leveraging the time-series extension provided by TimescaleDB,
#     this database handles write-intensive location data and supports
#     efficient queries for route optimization, historical analysis, and
#     geospatial queries.
#   - The endpoint is sensitive because it exposes the host and port
#     information of the TimescaleDB. Also, database credentials are
#     typically handled securely in a credentials store or Vault,
#     separate from Terraform state unless necessary.
#
# Usage:
#   - Refer to this output from application configuration or secret
#     management solutions to dynamically inject database connection strings.
#
output "tracking_service_db_endpoint" {
  description = "Primary TimescaleDB endpoint for GPS data storage and retrieval. Format: fully qualified domain name with port number."
  value       = "${module.tracking_service.timescaledb_endpoint}"
  sensitive   = true
}


###############################
# TRACKING SERVICE REGIONS
###############################
# Description:
#   - Provides a high-level overview of all AWS regions where the tracking
#     service is actively deployed. This output is crucial for ensuring a
#     consistent multi-region service footprint that supports global coverage,
#     low-latency connections, and active-active or active-passive failover
#     strategies.
#   - Helps other modules or orchestration layers (e.g., DNS, load balancers,
#     observer services) know where the tracking service cluster is running.
#
# Usage:
#   - Useful in routing logic, such as directing traffic to the closest
#     region or balancing load across multiple regions.
#
output "tracking_service_regions" {
  description = "List of AWS regions where tracking service is deployed for high availability."
  value       = "${module.tracking_service.deployed_regions}"
  sensitive   = false
}


###############################
# TRACKING SERVICE API ENDPOINTS
###############################
# Description:
#   - A comprehensive map of API endpoints for the tracking service, keyed by
#     region or other relevant identifiers. Each entry contains the service
#     URL and an associated health check URL to enable both programmatic
#     verification of service availability and integration with external
#     monitoring or load balancing solutions.
#   - This allows for region-specific routing of requests, ensuring minimal
#     round-trip latency and the ability to proactively discover and
#     bypass any service disruptions in a particular deployment region.
#
# Usage:
#   - Consumed by front-end mobile apps, backend services, or DevOps tools
#     that require environment-aware endpoint configuration and health check
#     orchestration in an automated pipeline or runtime environment.
#
output "tracking_service_api_endpoints" {
  description = "Map of regional API endpoints for the tracking service with their corresponding health check URLs."
  value       = "${module.tracking_service.api_endpoints}"
  sensitive   = false
}