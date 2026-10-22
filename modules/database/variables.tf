variable "name" {
  description = "Name prefix for resources, for example boctrust-staging."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the DB subnet group (at least two AZs)."
  type        = list(string)
}

variable "allowed_security_groups" {
  description = "Security groups (the ECS services) allowed to connect on 5432, keyed by a static label so for_each is known at plan time."
  type        = map(string)
  default     = {}
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  description = "Cheapest sensible default. Graviton (t4g) is cheaper than t3."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Initial storage in GiB."
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB. Set equal to allocated_storage to disable."
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "Standby in a second AZ. Doubles instance cost, so production only."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Automated backup retention. 1 to 35 days."
  type        = number
  default     = 7
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "skip_final_snapshot" {
  description = "Set true only for throwaway environments."
  type        = bool
  default     = false
}

variable "db_name" {
  type    = string
  default = "boctrust"
}

variable "master_username" {
  type    = string
  default = "boctrust_admin"
}
