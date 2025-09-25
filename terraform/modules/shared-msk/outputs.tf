output "cluster_arn" {
  description = "The ARN of the MSK cluster"
  value       = var.create_shared_msk ? aws_msk_cluster.shared_dev[0].arn : null
}

output "bootstrap_brokers" {
  description = "The bootstrap brokers for the MSK cluster"
  value       = var.create_shared_msk ? aws_msk_cluster.shared_dev[0].bootstrap_brokers : null
}
