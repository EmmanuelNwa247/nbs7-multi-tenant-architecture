#!/bin/bash

# Kafka Topic Validation Script
# This script validates that topics are properly created with prefixes

BOOTSTRAP_SERVERS="$1"
if [ -z "$BOOTSTRAP_SERVERS" ]; then
    echo "Usage: $0 <bootstrap-servers>"
    exit 1
fi

echo " Validating Kafka Topic Prefixing Implementation"
echo "Bootstrap Servers: $BOOTSTRAP_SERVERS"
echo "================================================"

# Test topic listing
echo " Listing all topics:"
kubectl run kafka-client --image=confluentinc/cp-kafka:7.4.0 --rm -it --restart=Never -- \
    kafka-topics --bootstrap-server "$BOOTSTRAP_SERVERS" --list

echo ""
echo " Topics by environment:"
for env in dev1 dev2 dev3; do
    echo "  $env environment topics:"
    kubectl run kafka-client --image=confluentinc/cp-kafka:7.4.0 --rm -it --restart=Never -- \
        kafka-topics --bootstrap-server "$BOOTSTRAP_SERVERS" --list | grep "^$env\." || echo "    No topics found for $env"
done

echo ""
echo " Testing topic isolation..."

# Test message publishing to different environments
for env in dev1 dev2 dev3; do
    echo "Publishing test message to $env.user-events"
    kubectl run kafka-producer-$env --image=confluentinc/cp-kafka:7.4.0 --rm -it --restart=Never -- \
        kafka-console-producer --bootstrap-server "$BOOTSTRAP_SERVERS" \
        --topic "$env.user-events" <<< "Test message from $env environment"
done

echo " Topic prefixing validation completed"
