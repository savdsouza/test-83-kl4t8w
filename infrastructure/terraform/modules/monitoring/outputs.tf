###############################################################################
# TERRAFORM OUTPUTS FOR THE MONITORING MODULE
# -----------------------------------------------------------------------------
# This file exposes multiple outputs that provide access to critical endpoints,
# credentials, and operational details of the monitoring stack. Each output
# corresponds to specific requirements from the technical and security
# specifications, ensuring a highly available, secure, and production-ready
# monitoring infrastructure.
###############################################################################

###############################################################################
# 1) PROMETHEUS_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Exposes the external URL for the load-balanced Prometheus server. This
#   endpoint requires HTTPS and supports health checks to verify service status.
#
# SECURITY & AVAILABILITY NOTES:
#   - Deployed behind a secure ingress controller or cloud load balancer.
#   - Typically protected by network policies and security groups.
#   - Health checks ensure only healthy Prometheus instances serve requests.
###############################################################################
output "prometheus_endpoint" {
  description = "Expose load-balanced Prometheus server endpoint URL with HTTPS and health check status."
  value       = format(
    "https://%s-prometheus.%s.example.com",
    helm_release.prometheus_stack.name,
    helm_release.prometheus_stack.namespace
  )
}

###############################################################################
# 2) GRAFANA_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Publishes the external URL for Grafana, enabling access to dashboards and
#   analytics. Traffic must flow over HTTPS, and availability zone routing
#   ensures failover if any zone is disrupted.
#
# SECURITY & AVAILABILITY NOTES:
#   - Protected by strict role-based access controls on dashboards.
#   - Contains powerful editing capabilities and must be locked down.
###############################################################################
output "grafana_endpoint" {
  description = "Expose load-balanced Grafana dashboard endpoint URL with HTTPS and availability zone routing."
  value       = format(
    "https://%s-grafana.%s.example.com",
    helm_release.grafana_deployment.name,
    helm_release.grafana_deployment.namespace
  )
}

###############################################################################
# 3) GRAFANA_ADMIN_PASSWORD
# -----------------------------------------------------------------------------
# PURPOSE:
#   Provides the sensitive admin password for Grafana, enabling administrators
#   to manage dashboards, data sources, and user permissions.
#
# SECURITY & AVAILABILITY NOTES:
#   - Marked as 'sensitive = true' to prevent logging and console output.
#   - Rotated automatically or on demand to meet security policy requirements.
###############################################################################
output "grafana_admin_password" {
  description = "Expose Grafana admin password with sensitive flag and auto-rotation policy."
  value       = var.grafana_admin_password
  sensitive   = true
}

###############################################################################
# 4) JAEGER_QUERY_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Provides the URL to the Jaeger query service, allowing developers and
#   operators to visualize distributed traces and debug latency across
#   microservices.
#
# SECURITY & AVAILABILITY NOTES:
#   - Serves trace data through a secured channel.
#   - High availability recommended via a load balancer or ingress.
###############################################################################
output "jaeger_query_endpoint" {
  description = "Expose load-balanced Jaeger query service endpoint URL with trace sampling configuration."
  value       = format(
    "https://%s-query.%s.example.com",
    helm_release.jaeger_deployment.name,
    helm_release.jaeger_deployment.namespace
  )
}

###############################################################################
# 5) JAEGER_COLLECTOR_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Exposes the URL to the Jaeger collector service, which aggregates spans and
#   forwards them to the configured storage backend with buffering and
#   retention settings.
#
# SECURITY & AVAILABILITY NOTES:
#   - Enforced SSL/TLS to secure span data in transit.
#   - Allocates buffer space and retention per organizational policies.
###############################################################################
output "jaeger_collector_endpoint" {
  description = "Expose load-balanced Jaeger collector endpoint URL with buffer and retention settings."
  value       = format(
    "https://%s-collector.%s.example.com",
    helm_release.jaeger_deployment.name,
    helm_release.jaeger_deployment.namespace
  )
}

###############################################################################
# 6) ELASTICSEARCH_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Reveals the external load-balanced URL for the Elasticsearch cluster used
#   by the monitoring stack. Houses logs and events for analytics and security
#   detection with index lifecycle policies.
#
# SECURITY & AVAILABILITY NOTES:
#   - Index lifecycle management ensures logs are retained securely and pruned
#     per compliance requirements.
#   - Must be accessible only by authorized ingestion services and Kibana.
###############################################################################
output "elasticsearch_endpoint" {
  description = "Expose load-balanced Elasticsearch endpoint URL with index lifecycle policies."
  value       = format(
    "https://%s-es.%s.example.com",
    helm_release.elk_deployment.name,
    helm_release.elk_deployment.namespace
  )
}

###############################################################################
# 7) KIBANA_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Provides the external URL for Kibana, enabling visualization of logs and
#   security dashboards. Typically run under HTTPS with integrated authentication.
#
# SECURITY & AVAILABILITY NOTES:
#   - Must enforce role-based access control, restricting log access to
#     authorized teams only.
#   - Integrates with single sign-on or native user database.
###############################################################################
output "kibana_endpoint" {
  description = "Expose load-balanced Kibana dashboard endpoint URL with security dashboard paths."
  value       = format(
    "https://%s-kibana.%s.example.com",
    helm_release.elk_deployment.name,
    helm_release.elk_deployment.namespace
  )
}

###############################################################################
# 8) MONITORING_NAMESPACE
# -----------------------------------------------------------------------------
# PURPOSE:
#   Communicates the Kubernetes namespace where the entire monitoring stack
#   resides. Resource quotas, network policies, and security contexts isolate
#   these workloads from other application namespaces.
#
# SECURITY & AVAILABILITY NOTES:
#   - Resource quotas prevent noisy neighbor issues within this namespace.
#   - Network policies allow only authorized traffic to the monitoring tools.
###############################################################################
output "monitoring_namespace" {
  description = "Expose Kubernetes namespace with resource quotas and network policies."
  value       = helm_release.prometheus_stack.namespace
}

###############################################################################
# 9) ALERT_MANAGER_ENDPOINT
# -----------------------------------------------------------------------------
# PURPOSE:
#   Makes the AlertManager endpoint available. It routes alerts from Prometheus
#   to configured channels with silencing, grouping, and escalation rules.
#
# SECURITY & AVAILABILITY NOTES:
#   - Restrict access to admin endpoints for alert routing to authorized staff.
#   - Integrates with Slack, PagerDuty, email, and other alert channels.
###############################################################################
output "alert_manager_endpoint" {
  description = "Expose load-balanced AlertManager endpoint URL with alert routing and silencing rules."
  value       = format(
    "https://%s-alertmanager.%s.example.com",
    helm_release.prometheus_stack.name,
    helm_release.prometheus_stack.namespace
  )
}

###############################################################################
# 10) MONITORING_BACKUP_BUCKET
# -----------------------------------------------------------------------------
# PURPOSE:
#   Identifies the S3 bucket name (or similar object storage) used for storing
#   and retaining monitoring data backups. Supports disaster recovery by
#   persisting snapshots and logs off-cluster.
#
# SECURITY & AVAILABILITY NOTES:
#   - Enforce secure access policies (SSE-KMS, private ACLs).
#   - Scheduled data lifecycles to manage costs and retention compliance.
###############################################################################
output "monitoring_backup_bucket" {
  description = "Expose S3 bucket name for monitoring data backups and retention."
  value       = format("monitoring-backup-%s", var.environment)
}

###############################################################################
# 11) MONITORING_AUDIT_LOG_GROUP
# -----------------------------------------------------------------------------
# PURPOSE:
#   Exposes the CloudWatch log group where monitoring stack audit events are
#   recorded. Ensures any configuration change, login attempt, or admin-level
#   action is properly tracked.
#
# SECURITY & AVAILABILITY NOTES:
#   - Logs must be persisted as read-only to comply with auditing standards.
#   - Monitor for suspicious activity or sign of intrusion.
###############################################################################
output "monitoring_audit_log_group" {
  description = "Expose CloudWatch log group for monitoring stack audit trails."
  value       = format("/aws/monitoring-audit-%s", var.environment)
}

###############################################################################
# 12) MONITORING_METRICS_NAMESPACE
# -----------------------------------------------------------------------------
# PURPOSE:
#   Discloses the CloudWatch metrics namespace used to track performance of the
#   monitoring stack itself. Storing metrics under a distinct namespace makes
#   them easy to locate, alert on, and graph within CloudWatch.
#
# SECURITY & AVAILABILITY NOTES:
#   - Writes restricted to authorized roles to prevent tampering.
#   - Helps unify FCAP (Functional, Capacity, Availability, Performance)
#     metrics in the enterprise environment.
###############################################################################
output "monitoring_metrics_namespace" {
  description = "Expose CloudWatch metrics namespace for monitoring stack performance."
  value       = format("MonitoringStack-%s", var.environment)
}