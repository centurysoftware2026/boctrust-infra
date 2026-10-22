variable "account_id" {
  description = "AWS account that owns the state bucket. Terraform refuses to run against any other account."
  type        = string
  default     = "852922980278"
}

variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "eu-west-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state."
  type        = string
  default     = "boctrust-terraform-state-852922980278"
}

variable "github_org" {
  description = "GitHub organisation allowed to assume the CI roles."
  type        = string
  default     = "centurysoftware2026"
}

variable "infra_repo" {
  description = "Repository allowed to plan and apply this Terraform from CI."
  type        = string
  default     = "boctrust-infra"
}

variable "budget_email" {
  description = "Receives monthly budget alerts. Set in terraform.tfvars (not committed)."
  type        = string
  default     = null
}
