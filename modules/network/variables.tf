variable "name" {
  description = "Name prefix for resources, for example boctrust-staging."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to span."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway (staging) instead of one per AZ (production)."
  type        = bool
  default     = true
}
