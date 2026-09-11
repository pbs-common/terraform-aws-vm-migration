# AWS Organizations resource-based DELEGATION POLICY, granting the delegated
# administrator account read access to the organization's structure, accounts and
# policies. Body is the AWS-documented example "View organization, OUs, accounts, and
# policies", narrowed to nothing beyond it:
# https://docs.aws.amazon.com/organizations/latest/userguide/security_iam_resource-based-policy-examples.html
#
# WHAT THIS DOES AND DOES NOT FIX -- recorded because the reason it was added is not
# the reason it is useful, and the next reader will otherwise assume it is load-bearing
# for MGN Global View. It is not.
#
# It was added while diagnosing an empty MGN Global View "Linked accounts" panel
# (mgn:ListManagedAccounts returns 0). Measured on 2026-09-11 BEFORE this policy
# existed, signed in to 911008223296 as AWSReservedSSO_AdministratorAccess, EVERY
# Organizations read API already succeeded:
#
#   DescribeOrganization ... OK      ListRoots ........................ OK
#   ListAccounts ........... OK      ListParents ...................... OK
#   DescribeAccount (self) . OK      ListChildren ..................... OK
#   DescribeAccount (other)  OK      ListOrganizationalUnitsForParent . OK
#   ListTagsForResource .... OK      ListDelegatedAdministrators ...... OK
#   ListDelegatedServicesForAccount  OK
#   ListAWSServiceAccessForOrganization ................................ OK
#
# because registering an account as a delegated administrator ALREADY grants it
# Organizations read-only access. So this policy changed no measured behaviour.
#
# The Global View denial is on the MGN side, not Organizations:
#
#   mgn:DescribeSourceServers --account-id <sibling account>
#     -> AccessDeniedException "not authorized to perform: mgn:DescribeSourceServers
#        on resource: arn:aws:mgn:*:*:*/* with an explicit deny in a RESOURCE-BASED
#        POLICY"
#
# and it reproduces identically from the MANAGEMENT account, which has full
# Organizations access by definition and cannot be helped by any delegation policy.
#
# So: this is HARDENING, not a fix. It makes the org-read grant explicit and
# reviewable instead of implicit in delegated-administrator status, which is worth
# having on its own terms -- but do not record it as the remedy for Global View, and
# do not remove it expecting Global View to change.
#
# HAZARD, and the reason this resource is commented at length: an organization has
# exactly ONE resource policy. The underlying API is PutResourcePolicy, which REPLACES
# the whole document rather than merging into it. This resource therefore OWNS the
# organization's single resource policy. If anyone adds another delegation -- backup
# policy management, tag policy management, SCP delegation -- it MUST be added to the
# statements below, not applied separately, or one will silently erase the other.
# Verified 2026-09-11: the organization had NO resource policy before this
# (DescribeResourcePolicy -> ResourcePolicyNotFoundException), so this creates it.

locals {
  # Exactly the actions in the AWS example. Deliberately no more: the same doc says
  # "include permissions to only the minimum required actions", and every additional
  # Organizations read delegated here is one the member account did not need.
  org_read_delegation_actions = [
    "organizations:DescribeOrganization",
    "organizations:DescribeOrganizationalUnit",
    "organizations:DescribeAccount",
    "organizations:DescribePolicy",
    "organizations:DescribeEffectivePolicy",
    "organizations:ListRoots",
    "organizations:ListOrganizationalUnitsForParent",
    "organizations:ListParents",
    "organizations:ListChildren",
    "organizations:ListAccounts",
    "organizations:ListAccountsForParent",
    "organizations:ListPolicies",
    "organizations:ListPoliciesForTarget",
    "organizations:ListTargetsForPolicy",
    "organizations:ListTagsForResource",
  ]
}

resource "aws_organizations_resource_policy" "org_read_delegation" {
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DelegatingNecessaryDescribeListActions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${var.delegated_administrator_account_id}:root" }
        Action    = local.org_read_delegation_actions
        Resource  = "*"
      }
    ]
  })

  tags = {
    Name      = "org-read-delegation"
    ManagedBy = "terraform-aws-vm-migration/environments/org-delegation"
  }
}

# Recovery path from lost state.
#
# Unlike the delegated-administrator registrations above, this cannot derive from live
# state: the AWS provider ships NO data source for the organization resource policy
# (checked against the provider schema for 6.62.0 -- only aws_organizations_organization
# matches), so there is nothing to intersect with.
#
# A static import block is therefore wrong here: with no policy live it fails the plan
# with "Cannot import non-existent remote object", which is the normal case. Instead the
# import is opt-in and empty by default, so a routine plan imports nothing and a recovery
# run sets the variable.
#
# This is deliberately NOT the hand-maintained "adopt existing?" flag rejected for the
# registrations. That flag would have to stay in sync with reality forever; this one is
# set for a single run and reset, and leaving it empty can only ever cause a create --
# which the PutResourcePolicy semantics above make safe to repeat.
#
#   terraform plan -var existing_resource_policy_id=rp-xxxxxxxx
import {
  for_each = var.existing_resource_policy_id == "" ? toset([]) : toset([var.existing_resource_policy_id])

  to = aws_organizations_resource_policy.org_read_delegation
  id = each.value
}
