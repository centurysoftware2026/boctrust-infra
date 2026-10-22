variable "name" {
  description = "Name prefix for resources, for example boctrust-staging."
  type        = string
}

variable "vpc_id" {
  description = "VPC the Cloud Map private namespace is attached to."
  type        = string
}

variable "service_names" {
  description = "Services that each get an ECR repository."
  type        = set(string)
  default     = ["user", "core", "admin", "notification", "cron"]
}

variable "namespace_name" {
  description = "Private DNS namespace used for service discovery between services."
  type        = string
  default     = "boctrust.internal"
}

variable "ecr_keep_images" {
  description = "Number of tagged images kept per repository. Older images are expired to save storage cost."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the cluster's service logs."
  type        = number
  default     = 14
}
