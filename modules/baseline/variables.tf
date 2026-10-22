variable "name" {
  type    = string
  default = "boctrust"
}

variable "budget_email" {
  description = "Address that receives budget alerts. Null skips the budget."
  type        = string
  default     = null
}

variable "monthly_budget_usd" {
  type    = number
  default = 150
}

variable "trail_log_retention_days" {
  description = "Days CloudTrail logs are kept in S3."
  type        = number
  default     = 365
}

variable "region" {
  type    = string
  default = "eu-west-1"
}
