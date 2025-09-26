# Variables for Tenant Environment Module

variable "tenant_name" {
  description = "Name of the tenant/environment (e.g., dev1, dev4, feature-auth-fix)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.tenant_name))
    error_message = "Tenant name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment_type" {
  description = "Type of environment (permanent, temporary, feature-branch)"
  type        = string
  default     = "temporary"

  validation {
    condition     = contains(["permanent", "temporary", "feature-branch"], var.environment_type)
    error_message = "Environment type must be one of: permanent, temporary, feature-branch."
  }
}

variable "created_by" {
  description = "Who created this environment (username, email, or CI/CD system)"
  type        = string
  default     = "terraform"
}

variable "feature_branch" {
  description = "Associated feature branch name (if applicable)"
  type        = string
  default     = ""
}

# TTL and Auto-cleanup Configuration
variable "ttl_hours" {
  description = "Time-to-live in hours for temporary environments (0 = no expiry)"
  type        = number
  default     = 0

  validation {
    condition     = var.ttl_hours >= 0 && var.ttl_hours <= 8760
    error_message = "TTL hours must be between 0 and 8760 (1 year)."
  }
}

variable "auto_cleanup_enabled" {
  description = "Enable automatic cleanup for temporary environments"
  type        = bool
  default     = false
}

# Resource Configuration
variable "resource_quotas" {
  description = "Resource quotas for the tenant namespace"
  type        = map(string)
  default = {
    "requests.cpu"    = "2"
    "requests.memory" = "4Gi"
    "limits.cpu"      = "4"
    "limits.memory"   = "8Gi"
    "pods"            = "25"
    "services"        = "10"
  }
}

# Kafka Configuration
variable "kafka_topics" {
  description = "List of Kafka topics to create for this tenant"
  type        = list(string)
  default = [
    "user-events",
    "audit-logs",
    "notifications",
    "data-sync",
    "error-events"
  ]
}

variable "kafka_partitions" {
  description = "Number of partitions per Kafka topic"
  type        = number
  default     = 3
}

variable "kafka_replication_factor" {
  description = "Replication factor for Kafka topics"
  type        = number
  default     = 2
}

variable "kafka_image" {
  description = "Docker image for Kafka operations"
  type        = string
  default     = "confluentinc/cp-kafka:7.4.0"
}

variable "kafka_port" {
  description = "Kafka broker port"
  type        = number
  default     = 9092
}

# Shared Infrastructure
variable "msk_bootstrap_servers" {
  description = "MSK cluster bootstrap servers"
  type        = string
}

# Network Policies
variable "enable_network_policies" {
  description = "Enable Kubernetes network policies for tenant isolation"
  type        = bool
  default     = true
}

# Labels and Annotations
variable "common_labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    "nbs-version" = "7"
    "managed-by"  = "terraform"
  }
}

variable "common_annotations" {
  description = "Common annotations to apply to all resources"
  type        = map(string)
  default = {}
}

# Environment-specific presets
variable "environment_presets" {
  description = "Pre-configured settings for different environment types"
  type = map(object({
    resource_quotas         = map(string)
    ttl_hours              = number
    auto_cleanup_enabled   = bool
    enable_network_policies = bool
  }))
  default = {
    "development" = {
      resource_quotas = {
        "requests.cpu"    = "1"
        "requests.memory" = "2Gi"
        "limits.cpu"      = "2"
        "limits.memory"   = "4Gi"
        "pods"           = "15"
        "services"       = "5"
      }
      ttl_hours              = 0
      auto_cleanup_enabled   = false
      enable_network_policies = true
    }
    "feature-branch" = {
      resource_quotas = {
        "requests.cpu"    = "0.5"
        "requests.memory" = "1Gi"
        "limits.cpu"      = "1"
        "limits.memory"   = "2Gi"
        "pods"           = "10"
        "services"       = "3"
      }
      ttl_hours              = 168  # 1 week
      auto_cleanup_enabled   = true
      enable_network_policies = true
    }
    "testing" = {
      resource_quotas = {
        "requests.cpu"    = "0.25"
        "requests.memory" = "512Mi"
        "limits.cpu"      = "0.5"
        "limits.memory"   = "1Gi"
        "pods"           = "5"
        "services"       = "2"
      }
      ttl_hours              = 24   # 1 day
      auto_cleanup_enabled   = true
      enable_network_policies = true
    }
  }
}