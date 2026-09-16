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
  description = "Member account registered as delegated administrator for every principal in service_principals -- MGN and CloudFormation StackSets (pbs-sdo-shared-workspace)."
  type        = string
}

# Both principals are REQUIRED, and the validation below enforces it. Extras are
# allowed, so a future Transform prerequisite can be added without a code change.
#
# Narrowing this set is not a harmless configuration choice. Since the import block
# in main.tf now uses for_each over THIS variable, it follows whatever is set here,
# so nothing downstream objects -- BOTH failure modes are silent, and this validation
# is the only thing standing between a narrowed set and real damage:
#
#   without mgn.amazonaws.com
#       plan reports "1 to import, 0 to add" and exits 0. MGN simply drops out of
#       management: still registered in AWS, no longer described by any code.
#       (An earlier static import block made this a hard error by accident; moving
#       to for_each removed that accidental guard, which is why this is explicit.)
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

# Set ONLY when rebuilding this directory's state from empty and an organization
# resource policy is already live. Empty on every normal run, which imports nothing.
# There is no data source for this resource, so it cannot be derived from live state
# the way the delegated-administrator imports are -- see resource-policy.tf.
#
# Find the id with:  aws organizations describe-resource-policy \
#                      --query 'ResourcePolicy.ResourcePolicySummary.Id' --output text
variable "existing_resource_policy_id" {
  description = "Id (rp-*) of an existing organization resource policy to adopt instead of creating one. Empty means create."
  type        = string
  default     = ""

  validation {
    condition     = var.existing_resource_policy_id == "" || can(regex("^rp-[0-9a-z]+$", var.existing_resource_policy_id))
    error_message = "existing_resource_policy_id must be empty or an organization resource policy id of the form rp-<alphanumeric>."
  }
}
