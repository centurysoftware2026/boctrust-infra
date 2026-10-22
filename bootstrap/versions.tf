terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Added after the first apply, once the bucket existed. The bucket is created by this same configuration.
  backend "s3" {
    bucket       = "boctrust-terraform-state-852922980278"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project     = "boctrust"
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}
