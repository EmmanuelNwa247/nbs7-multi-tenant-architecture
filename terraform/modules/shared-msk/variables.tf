variable "resource_prefix" {
  type        = string
  description = "Prefix for resource names"
  default     = "nbs7-test"
}

variable "create_shared_msk" {
  type        = bool
  description = "Create shared MSK cluster for multiple dev environments"
  default     = true
}

variable "environment_type" {
  type        = string
  default     = "development"
}

variable "msk_subnet_ids" {
  type = list(string)
}

variable "msk_ebs_volume_size" {
  type        = number
  default     = 50
}

variable "vpc_id" {
  type = string
}

variable "allowed_cidr_blocks" {
  type = list(string)
}

variable "kafka_version" {
  type    = string
  default = "3.6.0"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}
