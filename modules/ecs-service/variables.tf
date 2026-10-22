variable "name" {
  description = "Service name, for example user."
  type        = string
}

variable "env_name" {
  description = "Environment prefix, for example boctrust-staging."
  type        = string
}

variable "cluster_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "image" {
  description = "Full image URI including tag."
  type        = string
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "cpu" {
  description = "Fargate CPU units. 256 is the smallest."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "environment" {
  description = "Plain environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Environment variable name to Secrets Manager ARN (optionally with :json-key:: suffix)."
  type        = map(string)
  default     = {}
}

variable "log_group_name" {
  type = string
}

variable "namespace_id" {
  description = "Cloud Map namespace for service discovery. Null disables it."
  type        = string
  default     = null
}

variable "alb" {
  description = "Set to expose the service through the ALB. Null keeps it internal (cron, notification)."
  type = object({
    listener_arn      = string
    security_group_id = string
    priority          = number
    origin_secret     = string
    health_check_path = optional(string, "/health/liveness")
  })
  default   = null
  sensitive = true
}

variable "internal_ingress_cidr" {
  description = "VPC CIDR allowed to call this service directly (service-to-service through Cloud Map). Null disables."
  type        = string
  default     = null
}
