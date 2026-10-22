module "environment" {
  source = "../../modules/environment"

  name       = "boctrust-staging"
  env_prefix = "BOCTRUST_STAGING"
  node_env   = "staging"
  account_id = var.account_id

  # Cheapest viable shape. Staging can be torn down without leaving snapshots behind.
  single_nat_gateway    = true
  db_instance_class     = "db.t4g.micro"
  db_multi_az           = false
  db_backup_days        = 3
  db_protected          = false
  force_destroy_buckets = true
  secret_recovery_days  = 7

  github_environment = "staging"

  image_tag             = var.image_tag
  service_desired_count = var.service_desired_count
}
