variable "name" {
  description = "Environment prefix, for example boctrust-staging."
  type        = string
}

variable "env_prefix" {
  description = "Prefix the backend reads its settings under: BOCTRUST_STAGING or BOCTRUST_PROD."
  type        = string
}

variable "node_env" {
  description = "Value of BOCTRUST_NODE_ENV: staging or production."
  type        = string
}

variable "account_id" {
  type = string
}

variable "single_nat_gateway" {
  type = bool
}

variable "db_instance_class" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

variable "db_backup_days" {
  type = number
}

variable "db_protected" {
  description = "True keeps deletion protection and a final snapshot. False is for throwaway environments."
  type        = bool
}

variable "force_destroy_buckets" {
  type = bool
}

variable "secret_recovery_days" {
  type = number
}

variable "github_environment" {
  description = "GitHub environment allowed to deploy: staging or production."
  type        = string
}

variable "image_tag" {
  description = "Tag for the first task definitions. The deploy pipeline registers later ones."
  type        = string
  default     = "initial"
}

variable "service_desired_count" {
  description = "Tasks per service. Keep 0 until the first images are pushed."
  type        = number
  default     = 0
}

variable "service_size" {
  description = "Fargate cpu and memory per service. Defaults are the smallest size."
  type = map(object({
    cpu    = number
    memory = number
  }))
  default = {}
}
