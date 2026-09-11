variable "aws_region" {
  description = "Region for the provider. AWS Organizations is global; this only sets the endpoint used."
  type        = string
  default     = "us-east-1"
}

# Intentionally has NO default and is NOT set in the committed .tfvars: this repo is
# public and has never committed a real AWS account ID.
#
# Supply it directly, as the README's worked example does:
#
#     export TF_VAR_delegated_administrator_account_id=<member account id>
#     # or: terraform plan -var delegated_administrator_account_id=<id>
#
# NOT via TF_VAR_EXTRAS. That secret is a JSON blob decoded into TF_VAR_* by the
# reusable plan/apply workflows, and this directory deliberately has no workflow
# (see README) -- so nothing would decode it and the variable would stay unset.
variable "delegated_administrator_account_id" {
  description = "Member account registered as the MGN delegated administrator (pbs-sdo-shared-workspace)."
  type        = string
}

# Both principals are REQUIRED, and the validation below enforces it. Extras are
# allowed, so a future Transform prerequisite can be added without a code change.
#
# Narrowing this set is not a harmless configuration choice -- each principal fails
# in its own way, and one of them fails silently:
#
#   without mgn.amazonaws.com
#       the import block in main.tf targets that for_each instance, so the plan
#       dies with "Configuration for import target does not exist"
#   without member.org.stacksets.cloudformation.amazonaws.com
#       the plan SUCCEEDS and reports "0 to add, 0 to change, 1 to destroy" --
#       it deregisters the live StackSets delegation and breaks AWS Transform's
#       deployments, with no error and a zero exit code
#
# The second is why this is a validation rather than a comment.
variable "service_principals" {
  description = "Service principals to delegate to that account. Must include both principals AWS Transform requires; extras are permitted."
  type        = set(string)
  default = [
    "mgn.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com",
  ]

  validation {
    condition = alltrue([
      for required in [
        "mgn.amazonaws.com",
        "member.org.stacksets.cloudformation.amazonaws.com",
      ] : contains(tolist(var.service_principals), required)
    ])
    error_message = "service_principals must include both \"mgn.amazonaws.com\" and \"member.org.stacksets.cloudformation.amazonaws.com\". AWS Transform needs both on one account: MGN to administer migrations, StackSets because it deploys with CallAs=DELEGATED_ADMIN. Removing the StackSets principal plans a DESTROY of the live delegation without erroring. Extra principals are allowed."
  }
}
