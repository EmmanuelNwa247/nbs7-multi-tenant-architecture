variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "cost_optimization" {
  description = "Enable cost optimization settings"
  type        = bool
  default     = true
}

variable "eks_admin_role_arn" {
  description = "IAM role ARN for EKS admin access"
  type        = string
}
