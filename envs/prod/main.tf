module "environment" {
  source = "../../modules/environment"

  name       = "boctrust-prod"
  env_prefix = "BOCTRUST_PROD"
  node_env   = "production"
  account_id = var.account_id

  # One NAT per AZ and a standby database. These are the main reasons production costs more.
  single_nat_gateway    = false
  db_instance_class     = "db.t4g.small"
  db_multi_az           = true
  db_backup_days        = 7
  db_protected          = true
  force_destroy_buckets = false
  secret_recovery_days  = 30

  github_environment = "production"

  image_tag             = var.image_tag
  service_desired_count = var.service_desired_count

  # Production services get more headroom than the smallest size. Revisit once real load is known.
  service_size = {
    core = { cpu = 512, memory = 1024 }
    user = { cpu = 512, memory = 1024 }
  }
}
