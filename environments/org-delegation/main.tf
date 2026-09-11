# AWS Organizations delegation for Application Migration Service (MGN).
#
# Runs in the ORGANIZATION MANAGEMENT ACCOUNT. See README.md in this directory.
#
# The registration this captures already exists in AWS (created 2026-09-11), so the
# import block below adopts it. Terraform would otherwise try to create it and fail
# with AccountAlreadyRegisteredException.

module "mgn_delegation" {
  source = "../../modules/mgn-organizations-delegation"

  delegated_administrator_account_id = var.delegated_administrator_account_id
  service_principals                 = var.service_principals
}

# Adopt the existing live MGN registration instead of creating it.
# ID format is "<account_id>/<service_principal>".
#
# Only MGN is imported. The StackSets registration does NOT exist yet, so Terraform
# creates it on the first apply -- there is nothing to adopt. A first plan of this
# directory is therefore "1 to import, 1 to add".
import {
  to = module.mgn_delegation.aws_organizations_delegated_administrator.this["mgn.amazonaws.com"]
  id = "${var.delegated_administrator_account_id}/mgn.amazonaws.com"
}
