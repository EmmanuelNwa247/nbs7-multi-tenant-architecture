#!/bin/bash
# Script to dynamically create new tenant environments
# Usage examples:
#   ./create-environment.sh dev6 temporary "dev-team" 168
#   ./create-environment.sh feature-api-v2 feature-branch "john.doe@company.com" 120 "feature/api-v2-refactor"

set -euo pipefail

# Parse arguments
TENANT_NAME="${1:-}"
ENVIRONMENT_TYPE="${2:-temporary}"
CREATED_BY="${3:-terraform}"
TTL_HOURS="${4:-72}"
FEATURE_BRANCH="${5:-}"

if [ -z "$TENANT_NAME" ]; then
    echo "Usage: $0 <tenant_name> [environment_type] [created_by] [ttl_hours] [feature_branch]"
    echo ""
    echo "Arguments:"
    echo "  tenant_name      - Name for the new tenant environment (required)"
    echo "  environment_type - Type: permanent, temporary, feature-branch (default: temporary)"
    echo "  created_by       - Who is creating this environment (default: terraform)"
    echo "  ttl_hours        - Hours until auto-cleanup (default: 72, 0 = never)"
    echo "  feature_branch   - Associated git branch (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 dev6"
    echo "  $0 dev7 temporary 'qa-team' 168"
    echo "  $0 feature-auth feature-branch 'john@company.com' 120 'feature/auth-fix'"
    exit 1
fi

# Validate tenant name
if ! echo "$TENANT_NAME" | grep -qE '^[a-z0-9-]+$'; then
    echo "ERROR: Tenant name must contain only lowercase letters, numbers, and hyphens"
    exit 1
fi

# Set resource quotas based on environment type
case "$ENVIRONMENT_TYPE" in
    "permanent")
        REQUESTS_CPU="2"
        REQUESTS_MEMORY="4Gi"
        LIMITS_CPU="4"
        LIMITS_MEMORY="8Gi"
        PODS="25"
        SERVICES="10"
        AUTO_CLEANUP="false"
        if [ "$TTL_HOURS" != "0" ]; then
            echo "WARNING: Permanent environments should not have TTL. Setting to 0."
            TTL_HOURS="0"
        fi
        ;;
    "temporary")
        REQUESTS_CPU="1"
        REQUESTS_MEMORY="2Gi"
        LIMITS_CPU="2"
        LIMITS_MEMORY="4Gi"
        PODS="15"
        SERVICES="5"
        AUTO_CLEANUP="true"
        ;;
    "feature-branch")
        REQUESTS_CPU="0.5"
        REQUESTS_MEMORY="1Gi"
        LIMITS_CPU="1"
        LIMITS_MEMORY="2Gi"
        PODS="10"
        SERVICES="3"
        AUTO_CLEANUP="true"
        ;;
    *)
        echo "ERROR: Environment type must be one of: permanent, temporary, feature-branch"
        exit 1
        ;;
esac

echo "=== Creating new tenant environment ==="
echo "Tenant Name: $TENANT_NAME"
echo "Environment Type: $ENVIRONMENT_TYPE"
echo "Created By: $CREATED_BY"
echo "TTL Hours: $TTL_HOURS"
echo "Feature Branch: $FEATURE_BRANCH"
echo "Auto Cleanup: $AUTO_CLEANUP"
echo ""

# Check if tenant already exists
if grep -q "\"$TENANT_NAME\"" dynamic-tenants.tf; then
    echo "ERROR: Tenant '$TENANT_NAME' already exists in dynamic-tenants.tf"
    exit 1
fi

# Create backup of current configuration
cp dynamic-tenants.tf dynamic-tenants.tf.backup.$(date +%s)

# Generate new tenant configuration block
TENANT_CONFIG=$(cat << EOF

    $TENANT_NAME = {
      environment_type     = "$ENVIRONMENT_TYPE"
      created_by          = "$CREATED_BY"
      feature_branch      = "$FEATURE_BRANCH"
      ttl_hours          = $TTL_HOURS
      auto_cleanup_enabled = $AUTO_CLEANUP
      resource_quotas = {
        "requests.cpu"    = "$REQUESTS_CPU"
        "requests.memory" = "$REQUESTS_MEMORY"
        "limits.cpu"      = "$LIMITS_CPU"
        "limits.memory"   = "$LIMITS_MEMORY"
        "pods"           = "$PODS"
        "services"       = "$SERVICES"
      }
    }
EOF
)

# Insert the new tenant configuration before the closing brace of tenant_environments
# This is a simple approach - in production you might want a more robust parser
sed -i.bak "/^  }$/i\\
$TENANT_CONFIG" dynamic-tenants.tf

# Remove the backup created by sed
rm dynamic-tenants.tf.bak

echo "✅ Tenant configuration added to dynamic-tenants.tf"
echo ""
echo "Next steps:"
echo "1. Review the changes in dynamic-tenants.tf"
echo "2. Run: terraform plan"
echo "3. Run: terraform apply"
echo ""
echo "To remove this tenant later, simply delete the '$TENANT_NAME' block from dynamic-tenants.tf"
echo "and run terraform apply."
echo ""

# Optional: Auto-apply if --apply flag is passed
if [ "${6:-}" = "--apply" ]; then
    echo "🚀 Auto-applying changes..."
    terraform plan
    read -p "Continue with apply? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply -auto-approve
        echo "✅ Tenant '$TENANT_NAME' has been created successfully!"
        
        # Show the new namespace
        echo ""
        echo "Kubernetes namespace details:"
        kubectl get namespace "$TENANT_NAME" -o yaml
    fi
fi