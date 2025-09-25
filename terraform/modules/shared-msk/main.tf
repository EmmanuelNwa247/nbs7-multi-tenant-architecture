locals {
  module_name = "shared-msk"
  module_serial_number = "2024092301"
  # Sized for multiple dev environments
  instance_type  = var.environment_type == "development" ? "kafka.m5.large" : "kafka.m5.xlarge"
  instance_count = var.environment_type == "development" ? 2 : 4 
}

# MSK Cluster for shared dev environments
resource "aws_msk_cluster" "shared_dev" {
  count = var.create_shared_msk ? 1 : 0
  cluster_name           = "${var.resource_prefix}-shared-dev-msk-cluster"
  kafka_version         = var.kafka_version
  number_of_broker_nodes = local.instance_count

  configuration_info {
    arn      = aws_msk_configuration.shared_dev_config[0].arn
    revision = 1 
  }

  broker_node_group_info {
    instance_type   = local.instance_type
    client_subnets  = var.msk_subnet_ids
    security_groups = [aws_security_group.shared_msk_sg[0].id]
    
    storage_info {
      ebs_storage_info {
        volume_size = var.msk_ebs_volume_size
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS_PLAINTEXT"
      in_cluster    = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.shared_msk_logs[0].name
      }
    }
  }

  tags = merge(
    {
      Environment = "shared-development"
      Purpose     = "multi-tenant-dev-environments"
      NBS7        = "true"
    },
    var.additional_tags
  )
}

resource "aws_msk_configuration" "shared_dev_config" {
  count          = var.create_shared_msk ? 1 : 0
  kafka_versions = [var.kafka_version]
  name           = "${var.resource_prefix}-shared-dev-msk-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable = true
delete.topic.enable = true
default.replication.factor = 2
min.insync.replicas = 2
num.io.threads = 16
num.network.threads = 8
num.partitions = 3
num.replica.fetchers = 4
replica.lag.time.max.ms = 30000
socket.receive.buffer.bytes = 102400
socket.request.max.bytes = 104857600
socket.send.buffer.bytes = 102400
unclean.leader.election.enable = true
zookeeper.session.timeout.ms = 18000
offsets.topic.replication.factor = 2
transaction.state.log.replication.factor = 2
log.retention.hours = 168
PROPERTIES
}

resource "aws_security_group" "shared_msk_sg" {
  count       = var.create_shared_msk ? 1 : 0
  name        = "${var.resource_prefix}-shared-msk-sg"
  description = "Security group for shared MSK cluster"
  vpc_id      = var.vpc_id

  tags = {
    Name = "shared-msk-sg"
    NBS7 = "true"
  }
}

resource "aws_security_group_rule" "shared_msk_plaintext" {
  count             = var.create_shared_msk ? 1 : 0
  from_port         = 9092
  to_port           = 9092
  protocol          = "tcp"
  type              = "ingress"
  security_group_id = aws_security_group.shared_msk_sg[0].id
  cidr_blocks       = var.allowed_cidr_blocks
}

resource "aws_cloudwatch_log_group" "shared_msk_logs" {
  count             = var.create_shared_msk ? 1 : 0
  name              = "${var.resource_prefix}-shared-msk-broker-logs"
  retention_in_days = 7

  tags = {
    NBS7 = "true"
  }
}
