###############################################################################
# OUTPUT: cluster_id
# -----------------------------------------------------------------------------
# This output exports the ECS cluster identifier for the authentication
# service. It is essential for cross-module references, particularly where
# other Terraform modules or resources require a direct link to the ECS cluster.
# This aligns with the system architecture blueprint (2.2.1 Core Components,
# Auth Service) and high availability requirements (2.5.1 Infrastructure
# Requirements/API Servers). It also supports integration with monitoring
# systems and other microservices needing cluster-level data.
###############################################################################
output "cluster_id" {
  description = <<EOT
ID of the ECS cluster running the authentication service. 
Used for service orchestration and monitoring throughout the system architecture.
EOT
  value = aws_ecs_cluster.auth.id
}

###############################################################################
# OUTPUT: cluster_arn
# -----------------------------------------------------------------------------
# This output exposes the ECS cluster ARN used for IAM and service mesh
# integration. Other resources or modules requiring the ARN explicitly can
# reference this output to apply IAM roles or integrate the Auth Service within
# a broader service mesh (2.3.1 Architecture Patterns/Service Mesh). By sharing
# the cluster ARN, we ensure that any role-based permissions or service discovery
# tasks can properly link back to this specific cluster.
###############################################################################
output "cluster_arn" {
  description = <<EOT
ARN of the ECS cluster for IAM and service integration purposes. 
Essential for advanced service mesh and role-based configurations.
EOT
  value = aws_ecs_cluster.auth.arn
}

###############################################################################
# OUTPUT: service_name
# -----------------------------------------------------------------------------
# Provides the name of the ECS service responsible for running the authentication
# microservice. This is useful for logging, monitoring, and referencing the
# service in load balancing or scaling configurations, as well as for external
# modules that need to identify this ECS service by name. References the high
# availability design (2.5.1) and the multi-service approach to container
# orchestration.
###############################################################################
output "service_name" {
  description = <<EOT
Name of the ECS service running the authentication service. 
Used for logging, monitoring, and cross-service references in load balancing or scaling.
EOT
  value = aws_ecs_service.auth.name
}

###############################################################################
# OUTPUT: security_group_id
# -----------------------------------------------------------------------------
# Exposes the ID of the security group attached to the authentication service.
# This is critical for controlling network access to the service, meeting the
# security architecture (2.4.2 Security Architecture) and ensuring isolation and
# compliance with cross-cutting security concerns. Downstream modules or
# resources (like load balancers, WAF, or other microservices) can reference this
# security group to configure ingress and egress rules appropriately.
###############################################################################
output "security_group_id" {
  description = <<EOT
ID of the security group controlling network access to the authentication service.
Facilitates secure traffic management and inter-service communication.
EOT
  value = aws_security_group.auth.id
}

###############################################################################
# OUTPUT: service_discovery_endpoint
# -----------------------------------------------------------------------------
# This output provides a service discovery endpoint used internally for
# communication within the service mesh (2.3.1 Architecture Patterns/Service
# Mesh). By exposing the combined service name and private DNS namespace, other
# services or modules can locate the authentication service without relying on
# static IPs or manually configured endpoints, enabling dynamic scaling and
# smooth failover within a distributed environment.
###############################################################################
output "service_discovery_endpoint" {
  description = <<EOT
Service discovery endpoint for internal service mesh communication, 
combining the AWS Cloud Map service name and private DNS namespace to enable 
dynamic discovery and integration with other microservices.
EOT
  value = "${aws_service_discovery_service.auth.name}.${aws_service_discovery_private_dns_namespace.auth.name}"
}

###############################################################################
# OUTPUT: health_check_endpoint
# -----------------------------------------------------------------------------
# Indicates the relative URI path used by the system to check the health of the
# authentication service. This is leveraged by load balancers and monitoring
# tools (see 2.4 Cross-Cutting Concerns) to confirm that the service is running
# properly and to remove unhealthy tasks from rotation, thus aligning with the
# high availability and fault tolerance design goals of the system.
###############################################################################
output "health_check_endpoint" {
  description = <<EOT
Health check endpoint for service monitoring and load balancing, 
used to validate that the authentication service is fully operational.
EOT
  value = "/auth/health"
}