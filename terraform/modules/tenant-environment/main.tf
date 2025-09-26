# Reusable Tenant Environment Module
# Optimized for dynamic provisioning of temporary environments

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Create tenant namespace with auto-cleanup annotations
resource "kubernetes_namespace" "tenant" {
  metadata {
    name = var.tenant_name

    labels = merge(var.common_labels, {
      "tenant"                    = var.tenant_name
      "environment-type"          = var.environment_type
      "auto-cleanup"              = var.auto_cleanup_enabled ? "true" : "false"
      "ttl"                      = var.ttl_hours > 0 ? "${var.ttl_hours}h" : ""
      "created-by"               = var.created_by
      "feature-branch"           = var.feature_branch != "" ? var.feature_branch : ""
      "kafka-tenant"             = var.tenant_name
    })

    annotations = merge(var.common_annotations, {
      "kafka.topic.prefix"      = "${var.tenant_name}."
      "kafka.bootstrap.servers" = var.msk_bootstrap_servers
      "created-at"              = timestamp()
      "expires-at"              = var.ttl_hours > 0 ? timeadd(timestamp(), "${var.ttl_hours}h") : ""
    })
  }
}

# Dynamic ConfigMap with tenant-specific configuration
resource "kubernetes_config_map" "tenant_config" {
  metadata {
    name      = "tenant-config"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  data = merge(
    {
      # Core Kafka configuration
      "bootstrap.servers"     = var.msk_bootstrap_servers
      "topic.prefix"         = "${var.tenant_name}."
      "consumer.group.prefix" = "${var.tenant_name}-"
      
      # Environment metadata
      "tenant.name"          = var.tenant_name
      "environment.type"     = var.environment_type
      "feature.branch"       = var.feature_branch
      "created.by"          = var.created_by
    },
    # Dynamic topic mapping
    {
      for topic in var.kafka_topics : 
      "topics.${topic}" => "${var.tenant_name}.${topic}"
    }
  )
}

# Resource quotas (configurable by environment type)
resource "kubernetes_resource_quota" "tenant_quota" {
  metadata {
    name      = "${var.tenant_name}-quota"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    hard = var.resource_quotas
  }
}

# Network policies for tenant isolation
resource "kubernetes_network_policy" "tenant_isolation" {
  count = var.enable_network_policies ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-isolation"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    policy_types = ["Ingress", "Egress"]
    pod_selector {}

    # Allow DNS
    egress {
      ports {
        port     = "53"
        protocol = "UDP"
      }
      ports {
        port     = "53" 
        protocol = "TCP"
      }
    }

    # Allow intra-namespace communication
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.tenant_name
          }
        }
      }
    }

    egress {
      to {
        namespace_selector {
          match_labels = {
            name = var.tenant_name
          }
        }
      }
    }

    # Allow Kafka access for labeled pods
    egress {
      to {}
      ports {
        port     = var.kafka_port
        protocol = "TCP"
      }
    }
  }
}

# Kafka topic initialization job
resource "kubernetes_job" "kafka_topic_init" {
  metadata {
    name      = "${var.tenant_name}-topic-init"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    template {
      metadata {
        labels = {
          app         = "kafka-topic-init"
          tenant      = var.tenant_name
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "kafka-admin"
          image = var.kafka_image

          command = ["/bin/bash"]
          args = [
            "-c",
            templatefile("${path.module}/scripts/init-topics.sh", {
              tenant_name      = var.tenant_name
              bootstrap_servers = var.msk_bootstrap_servers
              topics           = var.kafka_topics
              partitions       = var.kafka_partitions
              replication_factor = var.kafka_replication_factor
            })
          ]

          env {
            name  = "TENANT_NAME"
            value = var.tenant_name
          }

          env {
            name  = "KAFKA_BOOTSTRAP_SERVERS"
            value = var.msk_bootstrap_servers
          }
        }
      }
    }

    backoff_limit = 3
  }

  wait_for_completion = false
}

# Optional: Auto-cleanup CronJob for temporary environments
resource "kubernetes_cron_job" "cleanup_job" {
  count = var.auto_cleanup_enabled && var.ttl_hours > 0 ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-cleanup"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  spec {
    schedule = "0 */6 * * *"  # Check every 6 hours

    job_template {
      metadata {}

      spec {
        template {
          metadata {}

          spec {
            restart_policy = "OnFailure"

            container {
              name  = "cleanup"
              image = "alpine:3.18"

              command = ["/bin/sh"]
              args = [
                "-c",
                templatefile("${path.module}/scripts/cleanup-check.sh", {
                  tenant_name = var.tenant_name
                  ttl_hours   = var.ttl_hours
                })
              ]
            }

            service_account_name = kubernetes_service_account.cleanup_sa[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Service account for cleanup operations
resource "kubernetes_service_account" "cleanup_sa" {
  count = var.auto_cleanup_enabled ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-cleanup"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
}

# Role binding for cleanup operations
resource "kubernetes_role_binding" "cleanup_binding" {
  count = var.auto_cleanup_enabled ? 1 : 0

  metadata {
    name      = "${var.tenant_name}-cleanup"
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"  # In production, create a more restrictive role
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.cleanup_sa[0].metadata[0].name
    namespace = kubernetes_namespace.tenant.metadata[0].name
  }
}