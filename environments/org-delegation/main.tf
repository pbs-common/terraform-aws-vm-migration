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

# Adopts the MGN registration, which was made by hand before this code existed.
# ID format is "<account_id>/<service_principal>".
#
# Only MGN is imported, because only MGN predated this directory. The StackSets
# registration was CREATED by this configuration on the 2026-09-11 apply, so it
# needs no import block and must not be given one.
#
# Both registrations are now in state, so a plan today reports NO CHANGES. The
# import block is spent and kept only so the directory can be rebuilt from an
# empty state.
import {
  to = module.mgn_delegation.aws_organizations_delegated_administrator.this["mgn.amazonaws.com"]
  id = "${var.delegated_administrator_account_id}/mgn.amazonaws.com"
}
