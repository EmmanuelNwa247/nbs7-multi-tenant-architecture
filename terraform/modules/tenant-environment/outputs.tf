# Outputs for Tenant Environment Module

output "namespace_name" {
  description = "Name of the created Kubernetes namespace"
  value       = kubernetes_namespace.tenant.metadata[0].name
}

output "namespace_labels" {
  description = "Labels applied to the namespace"
  value       = kubernetes_namespace.tenant.metadata[0].labels
}

output "namespace_annotations" {
  description = "Annotations applied to the namespace"
  value       = kubernetes_namespace.tenant.metadata[0].annotations
}

output "tenant_name" {
  description = "Tenant name used for this environment"
  value       = var.tenant_name
}

output "environment_type" {
  description = "Type of environment created"
  value       = var.environment_type
}

output "kafka_topics" {
  description = "Map of Kafka topics created for this tenant"
  value = {
    for topic in var.kafka_topics : 
    topic => "${var.tenant_name}.${topic}"
  }
}

output "configmap_name" {
  description = "Name of the tenant configuration ConfigMap"
  value       = kubernetes_config_map.tenant_config.metadata[0].name
}

output "resource_quota_name" {
  description = "Name of the resource quota applied to the namespace"
  value       = kubernetes_resource_quota.tenant_quota.metadata[0].name
}

output "cleanup_enabled" {
  description = "Whether auto-cleanup is enabled for this environment"
  value       = var.auto_cleanup_enabled
}

output "ttl_hours" {
  description = "Time-to-live hours for this environment (0 = no expiry)"
  value       = var.ttl_hours
}

output "expires_at" {
  description = "Expiration timestamp for this environment (empty if no expiry)"
  value       = var.ttl_hours > 0 ? timeadd(timestamp(), "${var.ttl_hours}h") : ""
}

output "network_policies_enabled" {
  description = "Whether network policies are enabled for tenant isolation"
  value       = var.enable_network_policies
}

output "resource_quotas" {
  description = "Resource quotas applied to this tenant"
  value       = var.resource_quotas
}