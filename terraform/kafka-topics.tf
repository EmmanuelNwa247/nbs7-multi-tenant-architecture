# Kafka Topic Configuration for Multi-Tenant Environments

locals {
  # Define environments and their topic patterns
  environments = ["dev1", "dev2", "dev3"]

  # Common topic patterns used across NBS application
  base_topics = [
    "user-events",
    "audit-logs",
    "notifications",
    "data-sync",
    "error-events"
  ]
}

# Create the actual namespaces first
resource "kubernetes_namespace" "dev_environments" {
  for_each = toset(local.environments)

  metadata {
    name = each.value # Use each.value for sets, not each.key

    labels = {
      "environment"  = each.value
      "nbs-version"  = "7"
      "kafka-tenant" = each.value
      "cost-center"  = "NBS7"
    }

    annotations = {
      "kafka.topic.prefix"      = "${each.value}."
      "kafka.bootstrap.servers" = module.shared_msk.bootstrap_brokers
    }
  }
}

# ConfigMap for each environment with topic configuration
resource "kubernetes_config_map" "kafka_topic_config" {
  for_each = toset(local.environments)

  metadata {
    name      = "kafka-topic-config"
    namespace = each.value # Use each.value consistently
  }

  data = {
    # Bootstrap servers from MSK cluster
    "bootstrap.servers" = module.shared_msk.bootstrap_brokers

    # Environment-specific topic prefix
    "topic.prefix" = "${each.value}."

    # Pre-configured topic names for this environment
    "topics.user-events"   = "${each.value}.user-events"
    "topics.audit-logs"    = "${each.value}.audit-logs"
    "topics.notifications" = "${each.value}.notifications"
    "topics.data-sync"     = "${each.value}.data-sync"
    "topics.error-events"  = "${each.value}.error-events"

    # Kafka consumer group prefix (for isolation)
    "consumer.group.prefix" = "${each.value}-"
  }

  depends_on = [kubernetes_namespace.dev_environments]
}

# Resource quotas for each environment
resource "kubernetes_resource_quota" "env_quotas" {
  for_each = toset(local.environments)

  metadata {
    name      = "${each.value}-resource-quota"
    namespace = each.value # Direct reference since namespace name = environment name
  }

  spec {
    hard = {
      "requests.cpu"    = "4"
      "requests.memory" = "8Gi"
      "limits.cpu"      = "8"
      "limits.memory"   = "16Gi"
      "pods"            = "50"
      "services"        = "20"
    }
  }

  depends_on = [kubernetes_namespace.dev_environments]
}
