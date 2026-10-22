variable "name" {
  type = string
}

variable "alb_dns_name" {
  type = string
}

variable "origin_verify_secret" {
  type      = string
  sensitive = true
}

variable "services" {
  description = "Services reachable through CloudFront, each at /<service>/*."
  type        = set(string)
  default     = ["user", "core", "admin"]
}

variable "admin_site" {
  description = "Admin dashboard S3 origin served at the root. Null leaves the root answering 403."
  type = object({
    bucket_regional_domain_name = string
    origin_access_control_id    = string
  })
  default = null
}
