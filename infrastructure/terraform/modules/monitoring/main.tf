###############################################################################
# MONITORING INFRASTRUCTURE MODULE
# ---------------------------------------------------------------------------
# This Terraform module implements a comprehensive monitoring stack with
# security-focused configurations, including the creation of a dedicated
# Kubernetes namespace, Prometheus, Grafana, Jaeger, and an ELK stack. It
# integrates with AWS (hashicorp/aws ~> 4.0), Kubernetes (hashicorp/kubernetes
# ~> 2.0), and Helm (hashicorp/helm ~> 2.0). All resources leverage enhanced
# security controls, resource quotas, network policies, and advanced alerting.
###############################################################################

###############################################################################
# REQUIRED PROVIDERS WITH VERSION COMMENTS
# ---------------------------------------------------------------------------
# We explicitly set the required providers and versions here:
#  - hashicorp/aws version ~> 4.0
#  - hashicorp/kubernetes version ~> 2.0
#  - hashicorp/helm version ~> 2.0
###############################################################################
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"       # AWS provider ~> 4.0
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"       # Kubernetes provider ~> 2.0
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"       # Helm provider ~> 2.0
    }
  }
}

###############################################################################
# IMPORTED VARIABLES
# ---------------------------------------------------------------------------
# These variables are imported from "infrastructure/terraform/modules/monitoring/variables.tf":
#
#   1) environment                  (string)
#   2) vpc_id                       (string)
#   3) subnet_ids                   (list(string))
#   4) prometheus_retention_period  (string)
#   5) grafana_admin_password       (string, sensitive)
#   6) jaeger_sampling_rate         (number)
#   7) elk_storage_size             (string)
#   8) alert_notification_endpoints (map(string))
#   9) monitoring_tags              (map(string))
###############################################################################
variable "environment" {}
variable "vpc_id" {}
variable "subnet_ids" {}
variable "prometheus_retention_period" {}
variable "grafana_admin_password" { sensitive = true }
variable "jaeger_sampling_rate" {}
variable "elk_storage_size" {}
variable "alert_notification_endpoints" {}
variable "monitoring_tags" {}

###############################################################################
# LOCAL VALUES FOR DEMONSTRATION
# ---------------------------------------------------------------------------
# We define sample local values to simulate properties for the classes and
# function parameters. In a production environment, these might be passed
# from variables or derived from additional logic. They demonstrate how to
# satisfy the specification for "create_monitoring_namespace" and the four
# classes: PrometheusStack, GrafanaDeployment, JaegerDeployment, and ELKStack.
###############################################################################
locals {
  # -------------------------------------------------------------------------
  # SAMPLE PARAMETERS FOR create_monitoring_namespace FUNCTION
  # (namespace_name, resource_quotas, security_labels).
  # -------------------------------------------------------------------------
  monitoring_namespace_name = "monitoring-${var.environment}"

  # Example resource quotas for CPU and memory. Enhanced resource quotas
  # ensure the namespace has strict usage limits and fosters security.
  monitoring_resource_quotas = {
    limits.cpu    = "6"
    limits.memory = "8Gi"
    requests.cpu  = "3"
    requests.memory = "4Gi"
  }

  # Security labels can be used for advanced enforcement in policy engines.
  monitoring_security_labels = {
    "purpose"       = "monitoring"
    "team"          = "platform"
    "securityLevel" = "high"
  }

  # -------------------------------------------------------------------------
  # PROPERTIES FOR PrometheusStack (namespace, retention_period, alert_rules,
  # security_metrics, and resource_quotas).
  # -------------------------------------------------------------------------
  prometheus_stack_properties = {
    namespace        = local.monitoring_namespace_name
    retention_period = var.prometheus_retention_period
    alert_rules      = {
      # Example placeholder for security alert rules. Real-world usage would
      # typically load rule files or define them as code.
      "securityHighCpuUsage" = "instance_cpu_usage_seconds_total > 0.9"
      "securityHighMemUsage" = "container_memory_usage_bytes > 1000000000"
    }
    security_metrics = {
      # Example placeholders for custom security metrics collection
      "auditHttpErrors"   = "sum by (instance) (rate(http_requests_total{status=~'4..|5..'}[5m]))"
      "podSecurityEvents" = "count_over_time(kube_pod_security_policy{}[5m])"
    }
    resource_quotas = local.monitoring_resource_quotas
  }

  # -------------------------------------------------------------------------
  # PROPERTIES FOR GrafanaDeployment (namespace, admin_password, datasources,
  # security_dashboards, alert_channels).
  # -------------------------------------------------------------------------
  grafana_deployment_properties = {
    namespace           = local.monitoring_namespace_name
    admin_password      = var.grafana_admin_password
    datasources         = ["Prometheus", "Jaeger", "Elasticsearch"]
    security_dashboards = {
      # Keyed by dashboard title or UID
      "API Security Metrics"      = "api-security.json"
      "Infrastructure Security"   = "infra-security.json"
      "Authentication Monitoring" = "auth-monitoring.json"
    }
    alert_channels = var.alert_notification_endpoints
  }

  # -------------------------------------------------------------------------
  # PROPERTIES FOR JaegerDeployment (namespace, sampling_rate, storage_class,
  # security_processors, trace_aggregations).
  # -------------------------------------------------------------------------
  jaeger_deployment_properties = {
    namespace          = local.monitoring_namespace_name
    sampling_rate      = var.jaeger_sampling_rate
    storage_class      = "standard"
    security_processors = {
      # Placeholder to illustrate security-minded spans or trace tags
      "tagAuthFlows"             = true
      "advancedSecurityAnalysis" = true
    }
    trace_aggregations = {
      # Example aggregator definitions
      "loginTracesAggregate"     = "aggregate all login operationName"
      "highLatencyCallsAggregate"= "aggregate calls > 2s"
    }
  }

  # -------------------------------------------------------------------------
  # PROPERTIES FOR ELKStack (namespace, storage_size, node_configs,
  # security_processors, log_aggregations).
  # -------------------------------------------------------------------------
  elk_stack_properties = {
    namespace         = local.monitoring_namespace_name
    storage_size      = var.elk_storage_size
    node_configs      = {
      "elasticsearch.replicas"     = 3
      "elasticsearch.heapSize"     = "2g"
      "elasticsearch.securityMode" = "on"
    }
    security_processors = {
      # Example security log processors
      "anonymizeIPs"         = true
      "tokenizeSensitiveData"= true
    }
    log_aggregations = {
      # Example log aggregation for firewall logs or WAF logs
      "wafLogs"        = "Capture WAF events from ALB logs"
      "infraLogs"      = "Combine system logs from all nodes"
      "authErrorLogs"  = "Consolidate authentication failures"
    }
  }
}

###############################################################################
# FUNCTION: create_monitoring_namespace
# ----------------------------------------------------------------------------
# DESCRIPTION:
#   Creates a dedicated Kubernetes namespace for monitoring components with
#   enhanced resource quotas and security configurations.
# PARAMETERS (SIMULATED VIA LOCALS ABOVE):
#   - namespace_name    (string)
#   - resource_quotas   (map)
#   - security_labels   (map)
# STEPS:
#   1. Validate namespace name and configurations (implicit in config)
#   2. Create namespace with specified name
#   3. Apply enhanced resource quotas and limits
#   4. Add monitoring and security labels
#   5. Configure network policies
#   6. Setup RBAC policies
#   7. Apply security contexts
###############################################################################

# 2. Create namespace with specified name (labeling it for security and ID).
resource "kubernetes_namespace" "monitoring_ns" {
  metadata {
    name = local.monitoring_namespace_name
    labels = merge(
      {
        "app.kubernetes.io/part-of" = "monitoring"
      },
      local.monitoring_security_labels
    )
  }
}

# 3. Apply enhanced resource quotas and limits.
resource "kubernetes_resource_quota" "monitoring_ns_quota" {
  metadata {
    name      = "monitoring-quotas"
    namespace = kubernetes_namespace.monitoring_ns.metadata[0].name
  }

  spec {
    hard = {
      "limits.cpu"    = local.monitoring_resource_quotas.limits.cpu
      "limits.memory" = local.monitoring_resource_quotas.limits.memory
      "requests.cpu"  = local.monitoring_resource_quotas.requests.cpu
      "requests.memory" = local.monitoring_resource_quotas.requests.memory
    }
  }
}

# 5. Configure network policies (sample policy restricting external traffic).
resource "kubernetes_network_policy" "monitoring_ns_policy" {
  metadata {
    name      = "monitoring-network-policy"
    namespace = kubernetes_namespace.monitoring_ns.metadata[0].name
  }

  spec {
    pod_selector {}
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "team" = "platform"
          }
        }
      }
    }
    policy_types = ["Ingress", "Egress"]
  }
}

# 6. Setup RBAC policies (sample read-only cluster role for demonstration).
resource "kubernetes_role" "monitoring_ns_role" {
  metadata {
    name      = "monitoring-read-only"
    namespace = kubernetes_namespace.monitoring_ns.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "endpoints", "events"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "monitoring_ns_role_binding" {
  metadata {
    name      = "monitoring-read-only-binding"
    namespace = kubernetes_namespace.monitoring_ns.metadata[0].name
  }
  role_ref {
    kind = "Role"
    name = kubernetes_role.monitoring_ns_role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind = "ServiceAccount"
    name = "default"
    namespace = kubernetes_namespace.monitoring_ns.metadata[0].name
  }
}

###############################################################################
# CLASS: PrometheusStack
# ----------------------------------------------------------------------------
# DESCRIPTION:
#   Manages enhanced Prometheus monitoring stack deployment with security-
#   focused configurations.
# PROPERTIES:
#   - namespace
#   - retention_period
#   - alert_rules
#   - security_metrics
#   - resource_quotas
# FUNCTION: deploy
#   - Deploys enhanced Prometheus stack with security monitoring capabilities.
# STEPS:
#   (1) Configure Prometheus server with security optimizations
#   (2) Setup enhanced Alertmanager with security alert rules
#   (3) Configure comprehensive service monitors including security endpoints
#   (4) Setup recording rules for security metrics
#   (5) Configure optimized retention settings
#   (6) Setup security metric collectors
#   (7) Configure cross-stack correlation rules
#   (8) Setup high availability configurations
###############################################################################
resource "helm_release" "prometheus_stack" {
  name             = "prometheus-stack"
  namespace        = local.prometheus_stack_properties.namespace
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "45.6.0"  # Example chart version for demonstration
  cleanup_on_fail  = true

  # We are merging user-provided or default alert notification endpoints
  # into the Alertmanager configuration for security-based alerts.
  values = [
    jsonencode({
      alertmanager = {
        alertmanagerSpec = {
          config = <<EOT
route:
  receiver: 'global_receiver'
receivers:
- name: 'global_receiver'
  # Sending alerts to endpoints from var.alert_notification_endpoints
  # This is a simplified placeholder for demonstration.
  webhook_configs:
%{ for endpoint_name, endpoint_url in var.alert_notification_endpoints }
  - url: '${endpoint_url}'
%{ endfor }
EOT
        }
      }
      prometheus = {
        prometheusSpec = {
          retention  = local.prometheus_stack_properties.retention_period
          replicas   = 2
          scrapeInterval = "30s"
          # Security metrics can be configured or appended here.
        }
      }
      additionalPrometheusRulesMap = {
        security_alerts = {
          groups = [
            {
              name = "securityAlertRules"
              rules = [
                for rule_name, expr in local.prometheus_stack_properties.alert_rules :
                {
                  alert       = rule_name
                  expr        = expr
                  labels      = { severity = "high" }
                  annotations = {
                    description = "Fires on security rule: ${rule_name}"
                  }
                }
              ]
            }
          ]
        }
      }
    })
  ]

  # We attach standard tags, environment details, etc.
  set {
    name  = "global.prometheusLabels.environment"
    value = var.environment
  }

  set {
    name  = "global.prometheusLabels.owner"
    value = "monitoring-team"
  }

  # Apply module-wide default tags
  common_labels = var.monitoring_tags

  depends_on = [
    kubernetes_namespace.monitoring_ns
  ]
}

###############################################################################
# CLASS: GrafanaDeployment
# ----------------------------------------------------------------------------
# DESCRIPTION:
#   Manages enhanced Grafana deployment with security-focused dashboards.
# PROPERTIES:
#   - namespace
#   - admin_password
#   - datasources
#   - security_dashboards
#   - alert_channels
# FUNCTION: deploy
#   - Deploys Grafana with enhanced security monitoring capabilities.
###############################################################################
resource "helm_release" "grafana_deployment" {
  name             = "grafana"
  namespace        = local.grafana_deployment_properties.namespace
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = "6.56.0"  # Example chart version for demonstration
  cleanup_on_fail  = true

  # Securely setting the admin password from a sensitive variable
  set_sensitive {
    name  = "adminPassword"
    value = local.grafana_deployment_properties.admin_password
  }

  # Example partial Helm values for data sources and dashboards
  values = [
    jsonencode({
      sidecar = {
        dashboards = {
          enabled = true
          label   = "grafana_dashboard"
        }
        datasources = {
          enabled = true
          label   = "grafana_datasource"
        }
      }
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            for ds in local.grafana_deployment_properties.datasources : {
              name      = ds
              type      = lower(ds) == "prometheus" ? "prometheus" : lower(ds)
              url       = lower(ds) == "prometheus" ? "http://prometheus-stack-prometheus.${local.grafana_deployment_properties.namespace}.svc.cluster.local:9090" : ""
              access    = "proxy"
              isDefault = ds == "Prometheus" ? true : false
            }
          ]
        }
      }
    })
  ]

  # Tagging
  common_labels = var.monitoring_tags

  depends_on = [
    kubernetes_namespace.monitoring_ns,
    helm_release.prometheus_stack
  ]
}

###############################################################################
# CLASS: JaegerDeployment
# ----------------------------------------------------------------------------
# DESCRIPTION:
#   Manages enhanced Jaeger tracing deployment with security tracing
#   capabilities.
# PROPERTIES:
#   - namespace
#   - sampling_rate
#   - storage_class
#   - security_processors
#   - trace_aggregations
# FUNCTION: deploy
#   - Deploys Jaeger with enhanced security tracing capabilities.
###############################################################################
resource "helm_release" "jaeger_deployment" {
  name             = "jaeger"
  namespace        = local.jaeger_deployment_properties.namespace
  repository       = "https://jaegertracing.github.io/helm-charts"
  chart            = "jaeger"
  version          = "0.57.1"  # Example chart version for demonstration
  cleanup_on_fail  = true

  values = [
    jsonencode({
      storage = {
        # We can set the default storage to "elasticsearch" or "cassandra" etc.
        type = "elasticsearch"
        elasticsearch = {
          # For demonstration, referencing local storage_class
          host               = "elasticsearch-master.${local.jaeger_deployment_properties.namespace}.svc.cluster.local"
          indexPrefix        = "jaeger-span"
          elasticsearchTags  = true
          nodeSelector       = {}
          volumeClaimTemplate = {
            spec = {
              storageClassName = local.jaeger_deployment_properties.storage_class
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "10Gi"
                }
              }
            }
          }
        }
      }
      collector = {
        # Using the sampling_rate from the local property
        sampling = {
          # Basic example, real configuration is more complex
          options = {
            default_strategy = "probabilistic"
            param            = local.jaeger_deployment_properties.sampling_rate
          }
        }
      }
      # Example placeholders for security processors or advanced aggregator stubs
      "securityProcessors" : local.jaeger_deployment_properties.security_processors
      "traceAggregations"  : local.jaeger_deployment_properties.trace_aggregations
    })
  ]

  common_labels = var.monitoring_tags

  depends_on = [
    kubernetes_namespace.monitoring_ns
  ]
}

###############################################################################
# CLASS: ELKStack
# ----------------------------------------------------------------------------
# DESCRIPTION:
#   Manages enhanced ELK stack deployment with security logging capabilities
#   (Elasticsearch, Logstash, Kibana).
# PROPERTIES:
#   - namespace
#   - storage_size
#   - node_configs
#   - security_processors
#   - log_aggregations
# FUNCTION: deploy
#   - Deploys ELK stack with enhanced security logging capabilities.
###############################################################################
resource "helm_release" "elk_deployment" {
  name             = "elastic-stack"
  namespace        = local.elk_stack_properties.namespace
  repository       = "https://helm.elastic.co"
  chart            = "elastic-stack"
  version          = "7.17.3"  # Example chart version for demonstration
  cleanup_on_fail  = true

  values = [
    jsonencode({
      elasticsearch = {
        volumeClaimTemplate = {
          accessModes = ["ReadWriteOnce"]
          storageClassName = "gp2"  # Typically dynamic; just for example
          resources = {
            requests = {
              storage = local.elk_stack_properties.storage_size
            }
          }
        }
        # Additional node config from the local property
        nodeSelector  = {}
        replicas      = lookup(local.elk_stack_properties.node_configs, "elasticsearch.replicas", 3)
        extraEnvs     = []
        heapSize      = lookup(local.elk_stack_properties.node_configs, "elasticsearch.heapSize", "2g")
        securityMode  = lookup(local.elk_stack_properties.node_configs, "elasticsearch.securityMode", "on")
      }
      logstash = {
        enabled = true
        # Placeholders for advanced pipeline configurations
        pipelines = [
          {
            name = "security-pipeline"
            config = "input { beats {} } filter { mutate {} } output { elasticsearch {} }"
          }
        ]
      }
      kibana = {
        enabled = true
        # Potentially configure security dashboards or index patterns
      }
      # Example placeholders for security log processors or advanced aggregator stubs
      securityProcessors = local.elk_stack_properties.security_processors
      logAggregations    = local.elk_stack_properties.log_aggregations
    })
  ]

  common_labels = var.monitoring_tags

  depends_on = [
    kubernetes_namespace.monitoring_ns
  ]
}

###############################################################################
# EXPORTS
# ----------------------------------------------------------------------------
# The specification requires that we export an object named "monitoring_stack"
# of type object with these named members:
#   - prometheus_deployment
#   - grafana_deployment
#   - jaeger_deployment
#   - elk_deployment
#   - security_metrics
#   - alert_configurations
###############################################################################
output "monitoring_stack" {
  description = "Expose enhanced monitoring stack deployment details with security monitoring capabilities."
  value = {
    prometheus_deployment = {
      release_name  = helm_release.prometheus_stack.name
      release_chart = helm_release.prometheus_stack.chart
      namespace     = helm_release.prometheus_stack.namespace
    }
    grafana_deployment = {
      release_name  = helm_release.grafana_deployment.name
      release_chart = helm_release.grafana_deployment.chart
      namespace     = helm_release.grafana_deployment.namespace
    }
    jaeger_deployment = {
      release_name  = helm_release.jaeger_deployment.name
      release_chart = helm_release.jaeger_deployment.chart
      namespace     = helm_release.jaeger_deployment.namespace
    }
    elk_deployment = {
      release_name  = helm_release.elk_deployment.name
      release_chart = helm_release.elk_deployment.chart
      namespace     = helm_release.elk_deployment.namespace
    }
    security_metrics = local.prometheus_stack_properties.security_metrics
    alert_configurations = var.alert_notification_endpoints
  }
}