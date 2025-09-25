
# Kafka Topic Configuration
output "kafka_topic_configuration" {
  description = "Kafka topic configuration for each environment"
  value = {
    for env in local.environments : env => {
      namespace = env
      topics = {
        user_events   = "${env}.user-events"
        audit_logs    = "${env}.audit-logs"
        notifications = "${env}.notifications"
        data_sync     = "${env}.data-sync"
        error_events  = "${env}.error-events"
      }
      consumer_group_prefix = "${env}-"
      bootstrap_servers     = module.shared_msk.bootstrap_brokers
    }
  }
}
