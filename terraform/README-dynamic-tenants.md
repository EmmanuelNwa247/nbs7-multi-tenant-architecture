# Dynamic Multi-Tenant Architecture

This branch implements a reusable, dynamic tenant management system optimized for ephemeral environments and feature branch testing. It transforms the architecture from static tenant definitions to a flexible, module-based approach.

## Key Features

### Dynamic Tenant Creation
- Easy spin-up of new environments (`dev4`, `dev5`, `feature-xyz`)
- Automated cleanup for temporary environments with TTL
- Feature branch support with metadata tracking
- Resource tiering based on environment type

### DRY-Compliant Architecture
- Single module (`modules/tenant-environment/`) handles all tenant types
- Centralized configuration eliminates code repetition
- Consistent patterns across all environments
- Easy maintenance and updates

### Multi-Tenant Isolation
- Network policies for tenant isolation
- Resource quotas per environment
- Kafka topic prefixing with automated creation
- Namespace-based separation

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Shared Infrastructure                     │
├─────────────────────┬───────────────────────────────────────┤
│     Shared EKS      │           Shared MSK                  │
│   (One Cluster)     │        (One Kafka Cluster)           │
└─────────────────────┴───────────────────────────────────────┘
           │                            │
           ▼                            ▼
┌─────────────────────────────────────────────────────────────┐
│                 Tenant Namespaces                           │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│   dev1   │   dev2   │   dev3   │   dev4   │ feature-auth... │
│ (perm)   │ (perm)   │ (perm)   │ (temp)   │ (feature-br)    │
│ No TTL   │ No TTL   │ No TTL   │ 7d TTL   │ 5d TTL          │
└──────────┴──────────┴──────────┴──────────┴─────────────────┘
```

## Module Structure

```
modules/tenant-environment/
├── main.tf              # Core tenant resources
├── variables.tf         # Configurable parameters
├── outputs.tf          # Tenant information
└── scripts/
    ├── init-topics.sh   # Kafka topic creation
    └── cleanup-check.sh # Auto-cleanup logic
```

## Use Cases

### Permanent Environments
```hcl
dev1 = {
  environment_type     = "permanent"
  ttl_hours           = 0           # Never expires
  auto_cleanup_enabled = false
  resource_quotas = {
    "requests.cpu" = "2"
    "limits.cpu"   = "4"
    # ... full quotas
  }
}
```

### Temporary Environments
```hcl
dev4 = {
  environment_type     = "temporary"
  ttl_hours           = 168         # 1 week
  auto_cleanup_enabled = true
  resource_quotas = {
    "requests.cpu" = "1"            # Reduced resources
    "limits.cpu"   = "2"
    # ...
  }
}
```

### Feature Branch Environments
```hcl
feature-auth-fix = {
  environment_type     = "feature-branch"
  created_by          = "john.doe@company.com"
  feature_branch      = "feature/auth-token-fix"
  ttl_hours          = 120          # 5 days
  auto_cleanup_enabled = true
  resource_quotas = {
    "requests.cpu" = "0.5"          # Minimal resources
    "limits.cpu"   = "1"
    # ...
  }
}
```

## TTL and Auto-Cleanup Process

The Time-To-Live (TTL) system automatically manages the lifecycle of temporary environments to prevent resource waste and reduce costs.

### How TTL Works

1. **Environment Creation**
   - When a temporary environment is created, the current timestamp is stored in the namespace annotation `created-at`
   - If `ttl_hours > 0`, an `expires-at` timestamp is calculated and stored
   - A CronJob is created to periodically check the environment's age

2. **Cleanup Monitoring**
   - The cleanup CronJob runs every 6 hours for each tenant namespace
   - The cleanup script (`cleanup-check.sh`) compares the current time with the creation timestamp
   - If the environment age exceeds the TTL threshold, cleanup is initiated

3. **Cleanup Process**
   - The system verifies that `auto-cleanup=true` label is set on the namespace
   - Kafka topics with the tenant prefix are identified for cleanup (logged for now)
   - The entire Kubernetes namespace is deleted, which cascades to all contained resources
   - Cleanup success/failure is logged for auditing

### Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ttl_hours` | Hours until environment expires (0 = never) | 0 |
| `auto_cleanup_enabled` | Enable automatic cleanup process | false |
| `environment_type` | Controls default TTL behavior | temporary |

### Safety Features

- **Explicit opt-in**: Auto-cleanup requires both `ttl_hours > 0` AND `auto_cleanup_enabled = true`
- **Namespace labeling**: Only namespaces with `auto-cleanup=true` label can be automatically deleted
- **Audit trail**: All cleanup actions are logged with timestamps and reasons
- **Grace period**: 6-hour check interval prevents immediate deletion of environments

### Example TTL Scenarios

```bash
# Create a 3-day temporary environment
./scripts/create-environment.sh temp-testing temporary "qa-team" 72

# Create a 1-week feature branch environment  
./scripts/create-environment.sh feature-auth feature-branch "dev@company.com" 168 "feature/auth-fix"

# Check environment status
kubectl get namespace temp-testing -o jsonpath='{.metadata.annotations.expires-at}'
```

## Quick Start

### Create a New Environment
```bash
# Quick temporary environment
./scripts/create-environment.sh dev6

# Feature branch environment
./scripts/create-environment.sh feature-api-v2 feature-branch "john@company.com" 120 "feature/api-v2-refactor"

# Review and apply
terraform plan
terraform apply
```

### Verify Environment
```bash
# Check namespace
kubectl get namespace dev6

# Check Kafka topics
kubectl get configmap tenant-config -n dev6 -o yaml

# Check resource quotas
kubectl get resourcequota -n dev6
```

### Remove Environment
```bash
# Simply remove from dynamic-tenants.tf
# Delete the dev6 block and run:
terraform apply
```

## Configuration Options

### Environment Types
- **`permanent`**: No TTL, full resources, manual cleanup
- **`temporary`**: TTL-based cleanup, moderate resources
- **`feature-branch`**: Short TTL, minimal resources, branch tracking

### Resource Tiers
| Type | CPU Request | Memory Request | TTL | Auto-Cleanup |
|------|-------------|----------------|-----|--------------|
| Permanent | 2 cores | 4Gi | None | No |
| Temporary | 1 core | 2Gi | 1-7 days | Yes |
| Feature Branch | 0.5 cores | 1Gi | 1-7 days | Yes |

## Security Features

### Network Policies
Each tenant gets isolated network policies:
- **Default deny-all** traffic between namespaces
- **Allow intra-namespace** communication
- **Allow DNS** resolution
- **Allow Kafka access** for labeled pods only

### Resource Isolation
- **CPU/Memory quotas** per namespace
- **Pod limits** to prevent resource hogging
- **Service limits** for cost control

## Monitoring and Management

### Tenant Discovery
```bash
# List all tenant namespaces
kubectl get namespaces -l nbs-version=7,multi-tenant=true

# Show tenant metadata
kubectl get namespaces -l auto-cleanup=true -o custom-columns=NAME:.metadata.name,TYPE:.metadata.labels.environment-type,CREATED-BY:.metadata.labels.created-by,EXPIRES:.metadata.annotations.expires-at
```

### Cleanup Monitoring
```bash
# Check cleanup jobs
kubectl get cronjobs -A -l app=cleanup

# View cleanup logs
kubectl logs -l app=cleanup -n <tenant-name>
```

## Development

### Prerequisites
- Terraform >= 1.5.0
- kubectl configured for target EKS cluster
- AWS credentials with appropriate permissions

### Local Development
1. Clone the repository
2. Navigate to the terraform directory
3. Copy `terraform.tfvars.example` to `terraform.tfvars` and configure variables
4. Run `terraform init`
5. Run `terraform plan` to review changes
6. Run `terraform apply` to create infrastructure

### Contributing
1. Create a feature branch
2. Make changes to the tenant configuration or module
3. Test changes with `terraform plan`
4. Submit a pull request with a clear description of changes

## Troubleshooting

### Common Issues

**TTL not triggering cleanup**
- Verify `auto_cleanup_enabled = true` in tenant configuration
- Check that namespace has `auto-cleanup=true` label
- Review CronJob logs for errors

**Resource quota exceeded**
- Check current resource usage: `kubectl describe resourcequota -n <tenant>`
- Adjust quota limits in tenant configuration
- Scale down applications if necessary

**Network policy blocking traffic**
- Verify pod labels match network policy selectors
- Check that required labels are present: `kafka-client=true`, `expose-via-ingress=true`
- Review network policy rules for the specific tenant namespace