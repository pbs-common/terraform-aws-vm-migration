variable "aws_region" {
  description = "Region for the provider. AWS Organizations is global; this only sets the endpoint used."
  type        = string
  default     = "us-east-1"
}

# Intentionally has NO default and is NOT set in the committed .tfvars: this repo is
# public and has never committed a real AWS account ID. Supply it at apply time via
# the TF_VAR_EXTRAS secret ({"delegated_administrator_account_id":"..."}) or -var.
variable "delegated_administrator_account_id" {
  description = "Member account registered as the MGN delegated administrator (pbs-sdo-shared-workspace)."
  type        = string
}

variable "service_principals" {
  description = "Service principals to delegate to that account."
  type        = set(string)
  default = [
    "mgn.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
  ]
}
