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

# Adopts every live registration, one import per entry in var.service_principals.
# ID format is "<account_id>/<service_principal>".
#
# ONE import block with for_each, not one static block per principal, for two
# reasons:
#
#   1. It derives from the same variable the resource does, so adding a principal
#      cannot leave an uncovered registration behind. Two static blocks are two
#      places to remember.
#   2. Terraform 1.16.0 -- the version this repo pins -- honours only the FIRST of
#      several static import blocks targeting instances of one for_each resource.
#      No error, no warning: the others are silently ignored and the resources plan
#      as "will be created", which then fails with AccountAlreadyRegisteredException.
#      Measured on the real configuration against an empty state:
#
#        terraform 1.14.6   2 to import, 0 to add     (correct)
#        terraform 1.15.8   2 to import, 0 to add     (correct)
#        terraform 1.16.0   1 to import, 1 to add     (regression)
#        terraform 1.16.0, this for_each form
#                           2 to import, 0 to add     (correct)
#
# Import blocks are no-ops once their targets are in state, so this costs nothing
# on a normal run and is the whole recovery path from a lost state.
import {
  for_each = var.service_principals

  to = module.mgn_delegation.aws_organizations_delegated_administrator.this[each.value]
  id = "${var.delegated_administrator_account_id}/${each.value}"
}
