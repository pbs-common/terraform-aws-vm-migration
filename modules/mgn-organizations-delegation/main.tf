# Organization-level delegation of one or more service principals to a member
# account. Written for AWS Transform's MGN and CloudFormation StackSets pair, but
# the resource is generic -- nothing here is MGN-specific.
#
# SCOPE: these are AWS Organizations management-account resources. Only a principal
# in the management account can create them. A member-account caller is rejected by
# the precondition below AT PLAN TIME, naming both the required account and the
# actual one -- it never reaches the apply, and never sees the AccessDeniedException
# the API would otherwise return. See the environment's README for which account and
# role this is expected to run as.
#
# Trusted access (EnableAWSServiceAccess) is deliberately NOT managed here. The only
# resource that expresses it is `aws_organizations_organization`, which manages the
# WHOLE organization -- adopting it would put every other enabled service principal,
# and the organization itself, under this state file. It is read below instead.

data "aws_organizations_organization" "this" {}

data "aws_caller_identity" "current" {}

locals {
  enabled_service_principals = toset(data.aws_organizations_organization.this.aws_service_access_principals)

  # Principals asked for that do not yet have organization trusted access.
  missing_trusted_access = setsubtract(var.service_principals, local.enabled_service_principals)
}

resource "aws_organizations_delegated_administrator" "this" {
  for_each = var.service_principals

  account_id        = var.delegated_administrator_account_id
  service_principal = each.value

  lifecycle {
    precondition {
      condition = data.aws_caller_identity.current.account_id == data.aws_organizations_organization.this.master_account_id
      error_message = format(
        "Delegated administrators can only be registered from the organization management account (%s); this run is authenticated as %s.",
        data.aws_organizations_organization.this.master_account_id,
        data.aws_caller_identity.current.account_id,
      )
    }

    precondition {
      condition = !var.verify_trusted_access || !contains(local.missing_trusted_access, each.value)
      error_message = format(
        "Organization trusted access is not enabled for %s. Enable it from the management account first: aws organizations enable-aws-service-access --service-principal %s",
        each.value,
        each.value,
      )
    }

    precondition {
      condition = var.delegated_administrator_account_id != data.aws_organizations_organization.this.master_account_id
      error_message = format(
        "The management account (%s) cannot be its own delegated administrator; pass a member account ID.",
        data.aws_organizations_organization.this.master_account_id,
      )
    }
  }
}
