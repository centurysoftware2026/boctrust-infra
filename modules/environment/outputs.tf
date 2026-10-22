output "base_url" {
  description = "Dashboard at the root, APIs at /api/<service>/..."
  value       = "https://${module.edge.domain_name}"
}

output "nat_public_ips" {
  description = "Give these to vendors that allowlist source IPs."
  value       = module.network.nat_public_ips
}

output "repository_urls" {
  value = module.cluster.repository_urls
}

output "cluster_name" {
  value = module.cluster.cluster_name
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "db_init_task" {
  description = "Run once after the first apply to create the service databases."
  value = {
    family         = module.db_init.task_definition_family
    security_group = module.db_init.security_group_id
  }
}

output "admin_site_bucket" {
  value = module.admin_site.bucket_name
}

output "distribution_id" {
  value = module.edge.distribution_id
}

output "backend_deploy_role_arn" {
  value = module.ci_roles.backend_deploy_role_arn
}

output "admin_deploy_role_arn" {
  value = module.ci_roles.admin_deploy_role_arn
}

output "database_master_secret_arn" {
  value = module.database.master_secret_arn
}

output "secret_ids" {
  description = "Secrets Manager secrets to fill in by hand."
  value       = { for k, s in aws_secretsmanager_secret.service : k => s.name }
}
