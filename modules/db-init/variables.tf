variable "name" {
  type = string
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

variable "db_endpoint" {
  type = string
}

variable "db_master_secret_arn" {
  description = "RDS-managed secret with username and password keys."
  type        = string
}

variable "databases" {
  description = "Databases to create if missing, one per service."
  type        = list(string)
  default     = ["user_service", "core_service", "admin_service"]
}

variable "log_group_name" {
  type = string
}
