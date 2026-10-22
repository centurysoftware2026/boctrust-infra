variable "bucket_name" {
  description = "Globally unique bucket name, for example boctrust-staging-kyc-852922980278."
  type        = string
}

variable "force_destroy" {
  description = "Allow deleting a non-empty bucket. Staging only."
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "Origins allowed to upload with signed URLs from a browser. Empty for native mobile only."
  type        = list(string)
  default     = []
}

variable "noncurrent_version_days" {
  type    = number
  default = 90
}
