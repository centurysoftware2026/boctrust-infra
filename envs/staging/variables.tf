variable "account_id" {
  type    = string
  default = "852922980278"
}

variable "region" {
  type    = string
  default = "eu-west-1"
}

variable "image_tag" {
  description = "Tag for the first task definitions. The deploy pipeline registers later ones."
  type        = string
  default     = "initial"
}

variable "service_desired_count" {
  description = "Tasks per service. Keep 0 until the first images are pushed, then raise."
  type        = number
  default     = 0
}
