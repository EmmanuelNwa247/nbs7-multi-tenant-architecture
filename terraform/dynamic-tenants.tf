# Dynamic Multi-Tenant Configuration
# Optimized for ephemeral environments and feature branch testing

locals {
  # Base tenant configurations
  tenant_environments = {
    # Permanent development environments
    dev1 = {
      environment_type     = "permanent"
      created_by          = "platform-team"
      feature_branch      = ""
      ttl_hours          = 0
      auto_cleanup_enabled = false
      resource_quotas = {
        "requests.cpu"    = "2"
        "requests.memory" = "4Gi"
        "limits.cpu"      = "4"
        "limits.memory"   = "8Gi"
        "pods"           = "25"
        "services"       = "10"
      }
    }

    dev2 = {
      environment_type     = "permanent"
      created_by          = "platform-team"
      feature_branch      = ""
      ttl_hours          = 0
      auto_cleanup_enabled = false
      resource_quotas = {
        "requests.cpu"    = "2"
        "requests.memory" = "4Gi"
        "limits.cpu"      = "4"
        "limits.memory"   = "8Gi"
        "pods"           = "25"
        "services"       = "10"
      }
    }

    dev3 = {
      environment_type     = "permanent"
      created_by          = "platform-team"
      feature_branch      = ""
      ttl_hours          = 0
      auto_cleanup_enabled = false
      resource_quotas = {
        "requests.cpu"    = "2"
        "requests.memory" = "4Gi"
        "limits.cpu"      = "4"
        "limits.memory"   = "8Gi"
        "pods"           = "25"
        "services"       = "10"
      }
    }

    # Temporary environments (can be easily added/removed)
    dev4 = {
      environment_type     = "temporary"
      created_by          = "dev-team"
      feature_branch      = ""
      ttl_hours          = 168  # 1 week
      auto_cleanup_enabled = true
      resource_quotas = {
        "requests.cpu"    = "1"
        "requests.memory" = "2Gi"
        "limits.cpu"      = "2"
        "limits.memory"   = "4Gi"
        "pods"           = "15"
        "services"       = "5"
      }
    }

    dev5 = {
      environment_type     = "temporary"
      created_by          = "qa-team"
      feature_branch      = ""
      ttl_hours          = 72   # 3 days
      auto_cleanup_enabled = true
      resource_quotas = {
        "requests.cpu"    = "1"
        "requests.memory" = "2Gi"
        "limits.cpu"      = "2"
        "limits.memory"   = "4Gi"
        "pods"           = "15"
        "services"       = "5"
      }
    }

    # Feature branch environments (example)
    feature-auth-fix = {
      environment_type     = "feature-branch"
      created_by          = "john.doe@company.com"
      feature_branch      = "feature/auth-token-fix"
      ttl_hours          = 168  # 1 week
      auto_cleanup_enabled = true
      resource_quotas = {
        "requests.cpu"    = "0.5"
        "requests.memory" = "1Gi"
        "limits.cpu"      = "1"
        "limits.memory"   = "2Gi"
        "pods"           = "10"
        "services"       = "3"
      }
    }

    feature-user-service = {
      environment_type     = "feature-branch"
      created_by          = "jane.smith@company.com"
      feature_branch      = "feature/user-service-refactor"
      ttl_hours          = 120  # 5 days
      auto_cleanup_enabled = true
      resource_quotas = {
        "requests.cpu"    = "0.5"
        "requests.memory" = "1Gi"
        "limits.cpu"      = "1"
        "limits.memory"   = "2Gi"
        "pods"           = "10"
        "services"       = "3"
      }
    }
  }

  # Common configuration applied to all tenants
  common_tenant_config = {
    kafka_topics = [
      "user-events",
      "audit-logs",
      "notifications",
      "data-sync",
      "error-events"
    ]
    kafka_partitions       = 3
    kafka_replication_factor = 2
    enable_network_policies = true
    
    common_labels = {
      "nbs-version"    = "7"
      "managed-by"     = "terraform"
      "cost-center"    = "NBS7"
      "multi-tenant"   = "true"
    }
  }
}

# Create tenant environments using the reusable module
module "tenant_environments" {
  for_each = local.tenant_environments
  
  source = "./modules/tenant-environment"
  
  # Basic tenant configuration
  tenant_name          = each.key
  environment_type     = each.value.environment_type
  created_by          = each.value.created_by
  feature_branch      = each.value.feature_branch
  
  # TTL and cleanup configuration
  ttl_hours           = each.value.ttl_hours
  auto_cleanup_enabled = each.value.auto_cleanup_enabled
  
  # Resource configuration
  resource_quotas = each.value.resource_quotas
  
  # Kafka configuration (from common config)
  kafka_topics            = local.common_tenant_config.kafka_topics
  kafka_partitions        = local.common_tenant_config.kafka_partitions
  kafka_replication_factor = local.common_tenant_config.kafka_replication_factor
  
  # Network policies
  enable_network_policies = local.common_tenant_config.enable_network_policies
  
  # Shared infrastructure
  msk_bootstrap_servers = module.shared_msk.bootstrap_brokers
  
  # Labels
  common_labels = merge(local.common_tenant_config.common_labels, {
    "environment-type" = each.value.environment_type
    "created-by"      = each.value.created_by
  })
  
  depends_on = [module.shared_eks, module.shared_msk]
}

# Helper data source for tenant management
data "kubernetes_namespaces" "tenant_namespaces" {
  metadata {
    labels = {
      "nbs-version"  = "7"
      "multi-tenant" = "true"
    }
  }
  
  depends_on = [module.tenant_environments]
}