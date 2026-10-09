terraform {
  required_version = "1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
    # For the local-exec provisioner that zips and uploads the webhook forwarder
    # Lambda's code during apply.
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}
