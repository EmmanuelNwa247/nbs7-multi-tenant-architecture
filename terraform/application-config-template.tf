# Application Configuration Template for Multi-Tenant Kafka

# application deployment showing topic prefix usage
resource "kubernetes_deployment" "sample_app" {
  for_each = toset(local.environments)

  metadata {
    name      = "sample-kafka-app"
    namespace = kubernetes_namespace.dev_environments[each.key].metadata[0].name

    labels = {
      app         = "sample-kafka-app"
      environment = each.key
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app         = "sample-kafka-app"
        environment = each.key
      }
    }

    template {
      metadata {
        labels = {
          app         = "sample-kafka-app"
          environment = each.key
        }
      }

      spec {
        container {
          name  = "kafka-app"
          image = "confluentinc/cp-kafka:7.4.0"

          command = ["/bin/bash", "-c", "sleep infinity"]

          env_from {
            config_map_ref {
              name = kubernetes_config_map.kafka_topic_config[each.key].metadata[0].name
            }
          }

          env {
            name  = "ENVIRONMENT"
            value = each.key
          }

          env {
            name  = "KAFKA_CONSUMER_GROUP"
            value = "${each.key}-sample-app"
          }
        }
      }
    }
  }
}
