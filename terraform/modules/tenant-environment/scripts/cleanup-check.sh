#!/bin/sh
# Auto-cleanup checker for temporary tenant environments

set -e

TENANT_NAME="${tenant_name}"
TTL_HOURS=${ttl_hours}

echo "=== Auto-cleanup check for tenant: $TENANT_NAME ==="
echo "TTL: $TTL_HOURS hours"

# Get current timestamp and namespace creation time
CURRENT_TIME=$(date +%s)
CREATED_AT=$(kubectl get namespace $TENANT_NAME -o jsonpath='{.metadata.annotations.created-at}' 2>/dev/null || echo "")

if [ -z "$CREATED_AT" ]; then
  echo "ERROR: Could not retrieve creation timestamp for namespace $TENANT_NAME"
  exit 1
fi

# Convert ISO timestamp to epoch
CREATED_EPOCH=$(date -d "$CREATED_AT" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$CREATED_AT" "+%s" 2>/dev/null)

if [ -z "$CREATED_EPOCH" ]; then
  echo "ERROR: Could not parse creation timestamp: $CREATED_AT"
  exit 1
fi

# Calculate age in hours
AGE_SECONDS=$((CURRENT_TIME - CREATED_EPOCH))
AGE_HOURS=$((AGE_SECONDS / 3600))

echo "Namespace created at: $CREATED_AT"
echo "Current age: $AGE_HOURS hours"
echo "TTL threshold: $TTL_HOURS hours"

# Check if cleanup is needed
if [ $AGE_HOURS -ge $TTL_HOURS ]; then
  echo "⚠️  Tenant $TENANT_NAME has exceeded TTL ($AGE_HOURS >= $TTL_HOURS hours)"
  echo "Initiating cleanup process..."
  
  # Check if namespace has the auto-cleanup label
  AUTO_CLEANUP=$(kubectl get namespace $TENANT_NAME -o jsonpath='{.metadata.labels.auto-cleanup}' 2>/dev/null || echo "false")
  
  if [ "$AUTO_CLEANUP" = "true" ]; then
    echo "🧹 Auto-cleanup is enabled, proceeding with deletion..."
    
    # Delete Kafka topics first
    echo "Cleaning up Kafka topics for tenant $TENANT_NAME..."
    # Note: This would need access to Kafka admin tools
    # For now, just log the action
    echo "  - Would delete topics: $TENANT_NAME.*"
    
    # Delete the namespace (this will cascade delete all resources)
    echo "Deleting namespace $TENANT_NAME..."
    kubectl delete namespace $TENANT_NAME --timeout=300s
    
    if [ $? -eq 0 ]; then
      echo "✅ Tenant $TENANT_NAME cleanup completed successfully"
    else
      echo "❌ Failed to delete namespace $TENANT_NAME"
      exit 1
    fi
  else
    echo "🚫 Auto-cleanup is disabled, skipping deletion"
    echo "To enable auto-cleanup, label the namespace with: auto-cleanup=true"
  fi
else
  REMAINING_HOURS=$((TTL_HOURS - AGE_HOURS))
  echo "✅ Tenant $TENANT_NAME is within TTL (expires in $REMAINING_HOURS hours)"
fi

echo "=== Cleanup check completed ==="