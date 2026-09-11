variable "delegated_administrator_account_id" {
  description = "Member account ID to register as delegated administrator. Must already be a member of the organization."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.delegated_administrator_account_id))
    error_message = "delegated_administrator_account_id must be a 12-digit AWS account ID."
  }
}

# MGN alone is enough to administer Application Migration Service. AWS Transform
# additionally deploys through CloudFormation StackSets with CallAs=DELEGATED_ADMIN,
# which requires the SAME account to hold the StackSets delegation as well:
# https://docs.aws.amazon.com/transform/latest/userguide/transform-vmware-connect-target-account.html
variable "service_principals" {
  description = "Organization service principals to delegate to the account. Each becomes one aws_organizations_delegated_administrator registration."
  type        = set(string)
  default     = ["mgn.amazonaws.com"]

  validation {
    condition     = length(var.service_principals) > 0
    error_message = "service_principals must not be empty; the module would otherwise manage nothing."
  }
}

variable "verify_trusted_access" {
  description = "Assert each service principal has organization trusted access enabled before registering a delegated administrator. Registration fails at the API otherwise, so this turns a late API error into an early plan-time one."
  type        = bool
  default     = true
}
