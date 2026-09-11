# AWS Organizations delegation for AWS Transform: both the MGN and CloudFormation
# StackSets service principals, delegated to one member account.
#
# Runs in the ORGANIZATION MANAGEMENT ACCOUNT. See README.md in this directory.
#
# BOTH registrations are already live, by different routes: MGN was registered by
# hand on 2026-09-11 before this code existed, and StackSets was created by this
# configuration on the apply the same day. The import block below adopts whichever
# already exist, so the directory is reproducible from an empty state; without it
# Terraform would try to create them and fail with AccountAlreadyRegisteredException.

module "mgn_delegation" {
  source = "../../modules/mgn-organizations-delegation"

  delegated_administrator_account_id = var.delegated_administrator_account_id
  service_principals                 = var.service_principals
}

# Which of the requested principals are ALREADY registered, read at plan time so the
# import block can cover exactly those and nothing else.
#
# This is what makes both directions work. An import block whose for_each is simply
# var.service_principals covers principals that do not exist yet, and adding one --
# the "extras are allowed" path this environment documents -- then fails the plan with
# "Cannot import non-existent remote object". Intersecting with what is live imports
# what exists and creates what does not. Measured:
#
#   empty state, both principals live    2 to import, 0 to add
#   a third principal not yet registered 2 to import, 1 to add
#
# CONSTRAINT this introduces, stated because it is a real edge and not free:
# ListDelegatedServicesForAccount raises AccountNotRegisteredException for an account
# that is a delegated administrator for NOTHING, so this directory cannot bootstrap a
# brand-new delegated administrator from zero -- the plan fails on the data source
# read before it can create anything. That is an accepted trade: this environment
# exists to describe an account that already holds a delegation, and the alternative
# (a hand-maintained "adopt existing?" flag) is a second place to keep in sync with
# reality, which is the defect this data source removes. To bootstrap a fresh account,
# register one principal by hand first, or drop this data source for that one run.
data "aws_organizations_delegated_services" "existing" {
  account_id = var.delegated_administrator_account_id
}

locals {
  already_registered = toset([
    for service in data.aws_organizations_delegated_services.existing.delegated_services :
    service.service_principal
  ])

  principals_to_import = setintersection(var.service_principals, local.already_registered)
}

# Adopts every registration that already exists. ID format is
# "<account_id>/<service_principal>".
#
# ONE import block with for_each, not one static block per principal, for two reasons:
#
#   1. It derives from live state rather than a hand-maintained list, so it cannot go
#      stale as principals are added or adopted.
#   2. Terraform 1.16.0 -- the version this repo pins -- honours only the FIRST of
#      several static import blocks targeting instances of one for_each resource. No
#      error, no warning: the rest are silently ignored and plan as "will be created",
#      which then fails with AccountAlreadyRegisteredException. Measured against an
#      empty state on the real configuration:
#
#        terraform 1.14.6   2 to import, 0 to add     (correct)
#        terraform 1.15.8   2 to import, 0 to add     (correct)
#        terraform 1.16.0   1 to import, 1 to add     (regression)
#        terraform 1.16.0, this for_each form
#                           2 to import, 0 to add     (correct)
#
# Import blocks are no-ops once their targets are in state, so this costs nothing on a
# normal run and is the whole recovery path from a lost state.
import {
  for_each = local.principals_to_import

  to = module.mgn_delegation.aws_organizations_delegated_administrator.this[each.value]
  id = "${var.delegated_administrator_account_id}/${each.value}"
}
