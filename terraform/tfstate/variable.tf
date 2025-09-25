variable "state_bucket_prefix" {
  description = "Prefix for the S3 bucket name"
  type        = string
  default     = "nbs7-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Name for the DynamoDB table used for state locking"
  type        = string
  default     = "nbs7-terraform-locks"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}