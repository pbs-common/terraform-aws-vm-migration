aws_region = "us-east-1"

# AWS Transform administers MGN through this account AND deploys through CloudFormation
# StackSets with CallAs=DELEGATED_ADMIN, so the same account needs both registrations.
service_principals = [
  "mgn.amazonaws.com",
  "member.org.stacksets.cloudformation.amazonaws.com",
]

# delegated_administrator_account_id is deliberately NOT set here: this repo is public.
# Supply it directly -- export TF_VAR_delegated_administrator_account_id=<id>, or
# -var. Not via TF_VAR_EXTRAS: that is decoded only by the reusable workflows, and
# this directory has none.
