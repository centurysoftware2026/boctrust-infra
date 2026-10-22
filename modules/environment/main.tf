data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_region" "current" {}

locals {
  # Ports come from each service's .env.example. secret_keys are the values that live in the
  # service's Secrets Manager secret and reach the container as <env_prefix>_<KEY>.
  services = {
    admin = {
      port     = 4201
      exposed  = true
      priority = 10
      bucket   = true
      env_keys = {
        PORT                     = "4201"
        DATABASE_SSL             = "true"
        CORE_SERVICE_BASE_URL    = "http://core.${local.namespace}:4203"
        USER_SERVICE_BASE_URL    = "http://user.${local.namespace}:4202"
        NOTIFICATION_SERVICE_URL = "http://notification.${local.namespace}:4204"
      }
      secret_keys = ["DATABASE_URL", "SENTRY_DSN", "INTERNAL_SERVICE_TOKEN"]
    }
    user = {
      port     = 4202
      exposed  = true
      priority = 20
      bucket   = true
      env_keys = {
        PORT                     = "4202"
        DATABASE_SSL             = "true"
        CORE_SERVICE_BASE_URL    = "http://core.${local.namespace}:4203"
        NOTIFICATION_SERVICE_URL = "http://notification.${local.namespace}:4204"
      }
      secret_keys = [
        "DATABASE_URL", "SENTRY_DSN", "AUTH_JWT_SECRET", "INTERNAL_SERVICE_TOKEN",
        "IDENTITY_ENCRYPTION_SECRET", "IDENTITY_HASH_SECRET",
        "SMILE_ID_API_KEY", "SMILE_ID_SIGNATURE_API_KEY", "SMILE_ID_PARTNER_ID",
        "DOJAH_SECRET_KEY", "DOJAH_APP_ID", "DOJAH_WEBHOOK_SECRET",
        "BUNCE_SECRET_KEY", "ZOHO_DESK_JWT_SECRET",
        "NOTIFICATIONS_SENDGRID_API_KEY", "NOTIFICATIONS_TERMII_API_KEY",
      ]
    }
    core = {
      port     = 4203
      exposed  = true
      priority = 30
      bucket   = false
      env_keys = {
        PORT                  = "4203"
        DATABASE_SSL          = "true"
        USER_SERVICE_BASE_URL = "http://user.${local.namespace}:4202"
      }
      secret_keys = [
        "DATABASE_URL", "SENTRY_DSN", "AUTH_JWT_SECRET", "INTERNAL_SERVICE_TOKEN",
        "CORE_BANKING_API_KEY", "BIODATA_ENCRYPTION_SECRET",
      ]
    }
    notification = {
      port     = 4204
      exposed  = false
      priority = 0
      bucket   = false
      env_keys = {
        PORT = "4204"
      }
      secret_keys = [
        "SENTRY_DSN", "INTERNAL_SERVICE_TOKEN", "TERMII_API_KEY", "SENDGRID_API_KEY",
        "FIREBASE_CLIENT_EMAIL", "FIREBASE_PRIVATE_KEY",
      ]
    }
    cron = {
      port     = 4005
      exposed  = false
      priority = 0
      bucket   = false
      env_keys = {
        CRON_PORT             = "4005"
        CORE_SERVICE_BASE_URL = "http://core.${local.namespace}:4203"
        USER_SERVICE_BASE_URL = "http://user.${local.namespace}:4202"
      }
      secret_keys = ["INTERNAL_SERVICE_TOKEN"]
    }
  }

  namespace = "boctrust.internal"

  # Used for the database name list and the DB access rule.
  databases = ["user_service", "core_service", "admin_service"]
}

module "network" {
  source = "../network"

  name               = var.name
  single_nat_gateway = var.single_nat_gateway
}

module "cluster" {
  source = "../ecs-cluster"

  name           = var.name
  vpc_id         = module.network.vpc_id
  namespace_name = local.namespace
}

module "alb" {
  source = "../alb"

  name              = var.name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "kyc_storage" {
  source = "../storage"

  bucket_name   = "${var.name}-kyc-${var.account_id}"
  force_destroy = var.force_destroy_buckets
}

# One secret per service holding the JSON keys listed in local.services[*].secret_keys.
# Terraform creates the empty container only. Set the value by hand, never in code:
#   aws secretsmanager put-secret-value --secret-id <name>/<service> --secret-string file://secret.json
# Every listed key must exist in the JSON (use "" for unused ones) or the task will not start.
# INTERNAL_SERVICE_TOKEN must hold the same value in every service: it authenticates service-to-service calls.
resource "aws_secretsmanager_secret" "service" {
  for_each = local.services

  name                    = "${var.name}/${each.key}"
  recovery_window_in_days = var.secret_recovery_days
}

module "service" {
  source   = "../ecs-service"
  for_each = local.services

  name               = each.key
  env_name           = var.name
  cluster_arn        = module.cluster.cluster_arn
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  namespace_id       = module.cluster.namespace_id
  log_group_name     = module.cluster.log_group_names[each.key]

  image                 = "${module.cluster.repository_urls[each.key]}:${var.image_tag}"
  container_port        = each.value.port
  desired_count         = var.service_desired_count
  cpu                   = try(var.service_size[each.key].cpu, 256)
  memory                = try(var.service_size[each.key].memory, 512)
  internal_ingress_cidr = module.network.vpc_cidr

  environment = merge(
    { for k, v in each.value.env_keys : "${var.env_prefix}_${k}" => v },
    each.value.bucket ? {
      "${var.env_prefix}_AWS_REGION"            = data.aws_region.current.region
      "${var.env_prefix}_AWS_S3_PRIVATE_BUCKET" = module.kyc_storage.bucket_name
    } : {},
    # Set here and not in local.services, because the edge module reads that local.
    each.key == "user" ? { "${var.env_prefix}_PUBLIC_BASE_URL" = "https://${module.edge.domain_name}/api/user" } : {},
    # The invite path is a placeholder: the dashboard has no invite route yet, so confirm it.
    each.key == "admin" ? {
      "${var.env_prefix}_FRONTEND_BASE_URL"         = "https://${module.edge.domain_name}"
      "${var.env_prefix}_FRONTEND_ADMIN_INVITE_URL" = "https://${module.edge.domain_name}/invite"
    } : {},
    { BOCTRUST_NODE_ENV = var.node_env },
  )

  secrets = {
    for k in each.value.secret_keys :
    "${var.env_prefix}_${k}" => "${aws_secretsmanager_secret.service[each.key].arn}:${k}::"
  }

  alb = each.value.exposed ? {
    listener_arn      = module.alb.listener_arn
    security_group_id = module.alb.security_group_id
    priority          = each.value.priority
    origin_secret     = module.alb.origin_verify_secret
  } : null
}

# Services that touch the KYC bucket get object access through their task role, not static keys.
resource "aws_iam_role_policy" "kyc_bucket" {
  for_each = { for k, v in local.services : k => v if v.bucket }

  name   = "kyc-bucket"
  role   = module.service[each.key].task_role_name
  policy = module.kyc_storage.object_access_policy_json
}

resource "aws_cloudwatch_log_group" "db_init" {
  name              = "/ecs/${var.name}/db-init"
  retention_in_days = 14
}

module "database" {
  source = "../database"

  name               = var.name
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  allowed_security_groups = merge(
    { for k, s in module.service : k => s.security_group_id },
    { "db-init" = module.db_init.security_group_id },
  )

  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_days
  deletion_protection   = var.db_protected
  skip_final_snapshot   = !var.db_protected
}

module "db_init" {
  source = "../db-init"

  name                 = var.name
  cluster_arn          = module.cluster.cluster_arn
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  db_endpoint          = module.database.endpoint
  db_master_secret_arn = module.database.master_secret_arn
  databases            = local.databases
  log_group_name       = aws_cloudwatch_log_group.db_init.name
}

module "admin_site" {
  source = "../admin-site"

  name             = var.name
  force_destroy    = var.force_destroy_buckets
  distribution_arn = module.edge.distribution_arn
}

module "edge" {
  source = "../edge"

  name                 = var.name
  alb_dns_name         = module.alb.dns_name
  origin_verify_secret = module.alb.origin_verify_secret
  services             = toset([for k, v in local.services : k if v.exposed])
  admin_site           = module.admin_site.origin
}

module "ci_roles" {
  source = "../ci-roles"

  name                  = var.name
  oidc_provider_arn     = data.aws_iam_openid_connect_provider.github.arn
  github_environment    = var.github_environment
  ecr_repository_arns   = values(module.cluster.repository_arns)
  cluster_arn           = module.cluster.cluster_arn
  ecs_role_arns         = flatten([for s in module.service : [s.task_role_arn, s.execution_role_arn]])
  admin_site_bucket_arn = module.admin_site.bucket_arn
  distribution_arn      = module.edge.distribution_arn
}
