# Kafka Topic Initialization Job
# This creates the actual topics in the MSK cluster

resource "kubernetes_job" "kafka_topic_init" {
  for_each = toset(local.environments)

  metadata {
    name      = "kafka-topic-init-${each.value}"
    namespace = each.value # Direct reference since namespace name = environment name
  }

  spec {
    template {
      metadata {
        labels = {
          app         = "kafka-topic-init"
          environment = each.value # Changed from each.key to each.value
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "kafka-admin"
          image = "confluentinc/cp-kafka:7.4.0"

          command = ["/bin/bash"]
          args = [
            "-c",
            <<-EOT
            echo "Creating topics for environment: ${each.value}"
            
            # Wait for Kafka to be ready
            kafka-topics --bootstrap-server ${module.shared_msk.bootstrap_brokers} --list --timeout-ms 10000 || exit 1
            
            # Create topics with environment prefix
            topics=(
              "${each.value}.user-events"
              "${each.value}.audit-logs" 
              "${each.value}.notifications"
              "${each.value}.data-sync"
              "${each.value}.error-events"
            )
            
            for topic in "$${topics[@]}"; do
              echo "Creating topic: $$topic"
              kafka-topics --bootstrap-server ${module.shared_msk.bootstrap_brokers} \
                --create \
                --topic $$topic \
                --partitions 3 \
                --replication-factor 2 \
                --if-not-exists || echo "Topic $$topic may already exist"
            done
            
            echo "Topic creation completed for ${each.value}"
            kafka-topics --bootstrap-server ${module.shared_msk.bootstrap_brokers} --list | grep "^${each.value}\."
            EOT
          ]

          env {
            name  = "KAFKA_BOOTSTRAP_SERVERS"
            value = module.shared_msk.bootstrap_brokers
          }
        }
      }
    }

    backoff_limit = 3
  }

  depends_on = [kubernetes_namespace.dev_environments, kubernetes_config_map.kafka_topic_config]
}
