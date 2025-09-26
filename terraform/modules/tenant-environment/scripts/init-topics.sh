#!/bin/bash
# Kafka Topic Initialization Script for Tenant: ${tenant_name}

set -euo pipefail

echo "=== Initializing Kafka topics for tenant: ${tenant_name} ==="

# Configuration
BOOTSTRAP_SERVERS="${bootstrap_servers}"
TENANT_NAME="${tenant_name}"
PARTITIONS=${partitions}
REPLICATION_FACTOR=${replication_factor}

# Topics to create
TOPICS=(
%{ for topic in topics ~}
    "${tenant_name}.${topic}"
%{ endfor ~}
)

echo "Bootstrap servers: $BOOTSTRAP_SERVERS"
echo "Creating topics with $PARTITIONS partitions and replication factor $REPLICATION_FACTOR"

# Wait for Kafka to be ready
echo "Waiting for Kafka cluster to be available..."
timeout 120s bash -c '
  until kafka-topics --bootstrap-server $BOOTSTRAP_SERVERS --list >/dev/null 2>&1; do
    echo "Waiting for Kafka..."
    sleep 5
  done
'

if [ $? -ne 0 ]; then
  echo "ERROR: Kafka cluster not available after 120 seconds"
  exit 1
fi

echo "Kafka cluster is available!"

# Create topics
for topic in "$${TOPICS[@]}"; do
  echo "Creating topic: $topic"
  
  if kafka-topics --bootstrap-server $BOOTSTRAP_SERVERS \
    --describe --topic "$topic" >/dev/null 2>&1; then
    echo "  Topic $topic already exists, skipping..."
  else
    kafka-topics --bootstrap-server $BOOTSTRAP_SERVERS \
      --create \
      --topic "$topic" \
      --partitions $PARTITIONS \
      --replication-factor $REPLICATION_FACTOR \
      --config retention.ms=604800000 \
      --config segment.ms=86400000
    
    if [ $? -eq 0 ]; then
      echo "  ✅ Topic $topic created successfully"
    else
      echo "  ❌ Failed to create topic $topic"
      exit 1
    fi
  fi
done

echo ""
echo "=== Topic creation completed for tenant: ${tenant_name} ==="
echo "Created topics:"
kafka-topics --bootstrap-server $BOOTSTRAP_SERVERS --list | grep "^${tenant_name}\\." | sort

echo ""
echo "=== Topic details ==="
for topic in "$${TOPICS[@]}"; do
  echo "Topic: $topic"
  kafka-topics --bootstrap-server $BOOTSTRAP_SERVERS --describe --topic "$topic"
  echo ""
done

echo "🎉 Tenant ${tenant_name} Kafka setup completed successfully!"