output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "namespace_id" {
  value = aws_service_discovery_private_dns_namespace.this.id
}

output "repository_urls" {
  description = "ECR repository URL per service."
  value       = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "log_group_names" {
  description = "CloudWatch log group per service."
  value       = { for k, g in aws_cloudwatch_log_group.service : k => g.name }
}

output "repository_arns" {
  value = { for k, r in aws_ecr_repository.service : k => r.arn }
}
