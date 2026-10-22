output "info" {
  description = "Everything needed to deploy and operate this environment."
  value = {
    base_url                   = module.environment.base_url
    nat_public_ips             = module.environment.nat_public_ips
    repository_urls            = module.environment.repository_urls
    cluster_name               = module.environment.cluster_name
    private_subnet_ids         = module.environment.private_subnet_ids
    db_init_task               = module.environment.db_init_task
    admin_site_bucket          = module.environment.admin_site_bucket
    distribution_id            = module.environment.distribution_id
    backend_deploy_role_arn    = module.environment.backend_deploy_role_arn
    admin_deploy_role_arn      = module.environment.admin_deploy_role_arn
    database_master_secret_arn = module.environment.database_master_secret_arn
    secret_ids                 = module.environment.secret_ids
  }
}
