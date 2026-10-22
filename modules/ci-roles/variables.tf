variable "name" {
  description = "Environment prefix, for example boctrust-staging."
  type        = string
}

variable "github_org" {
  type    = string
  default = "centurysoftware2026"
}

variable "oidc_provider_arn" {
  type = string
}

variable "backend_repo" {
  type    = string
  default = "boctrust-backend"
}

variable "github_environment" {
  description = "GitHub environment (staging or production) whose jobs may assume the deploy roles. Branch rules and approvals live on the environment."
  type        = string
}

variable "admin_repo" {
  type    = string
  default = "boctrust-admin"
}

variable "ecr_repository_arns" {
  type = list(string)
}

variable "cluster_arn" {
  type = string
}

variable "ecs_role_arns" {
  description = "Task and execution role ARNs the deploy may pass to ECS."
  type        = list(string)
}

variable "admin_site_bucket_arn" {
  type = string
}

variable "distribution_arn" {
  type = string
}
