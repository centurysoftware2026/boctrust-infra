variable "name" {
  type = string
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "distribution_arn" {
  description = "CloudFront distribution allowed to read the bucket."
  type        = string
}
