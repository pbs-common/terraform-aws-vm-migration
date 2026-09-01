terraform {
  required_version = "1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
  }

  # bucket/key/region supplied at `terraform init` time
  backend "s3" {
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}
