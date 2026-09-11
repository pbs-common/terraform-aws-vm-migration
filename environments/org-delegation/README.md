# org-delegation

AWS Organizations delegation for AWS Application Migration Service (MGN), captured as code.

## What this manages

Two `aws_organizations_delegated_administrator` registrations, both delegated to
**pbs-sdo-shared-workspace** and anchored to the organization management account:

| Service principal | Why AWS Transform needs it | Live as of 2026-09-11 |
|---|---|---|
| `mgn.amazonaws.com` | Administer Application Migration Service from a member account | Registered by hand, **imported** by this code |
| `member.org.stacksets.cloudformation.amazonaws.com` | Transform deploys through StackSets with `CallAs: DELEGATED_ADMIN` | Not yet registered, **created** by this code |

This lets migration operators administer MGN from a member account instead of the
management account, which is what the MGN and AWS Transform guides both recommend:

- <https://docs.aws.amazon.com/organizations/latest/userguide/services-that-can-integrate-application-migration.html#integrate-enable-da-application-migration>
- <https://docs.aws.amazon.com/transform/latest/userguide/transform-vmware-connect-target-account.html>

## Where it runs

**The organization management account**, not the migration account, and not the AD
account the rest of this repo targets. Only a management-account principal can call
`RegisterDelegatedAdministrator`; anywhere else the apply fails at the API. The module
carries a precondition that fails the plan with a clear message rather than letting the
apply get that far.

This directory is deliberately **not** wired into a GitHub Actions workflow. The existing
`OIDC_ROLE_ARN` secret targets the workload account, and pointing CI at a role with
management-account Organizations write access is a separate decision that should be made
explicitly rather than inherited from this change.

## State

Nothing has been applied from this directory yet -- the registration was made by hand
first and this code adopts it. It has **no backend state object yet**; pick a bucket/key
at `terraform init` time, consistent with the other environments.

## Applying

```console
export AWS_PROFILE=<management-account admin profile>
export TF_VAR_delegated_administrator_account_id=<member account id>

terraform init \
  -backend-config="bucket=<state bucket>" \
  -backend-config="key=org-delegation/terraform.tfstate" \
  -backend-config="region=us-east-1"

terraform plan -var-file org-delegation.tfvars
```

The first plan should report **1 to import, 1 to add, 0 to change, 0 to destroy**: the MGN
registration already exists and is adopted, the StackSets one does not yet exist and is
created. Anything else means the live state has drifted from what this code describes --
read the plan before applying it.

Applying this directory is therefore what actually creates the StackSets delegation. Until
someone runs that apply, AWS Transform's StackSets deployments will not work from this
account.

## Note: StackSets is delegated to other accounts too

`member.org.stacksets.cloudformation.amazonaws.com` was already registered to three other
accounts before this change -- pbs-ops-tools, pbs-security and pbs-logging -- and those
registrations are **not** managed here. AWS permits multiple StackSets delegated
administrators, so adding this account does not displace them, and this state file must
never be allowed to think it owns them.

If a future change needs to manage those too, add them as separate module instances with
their own import blocks. Do not widen `delegated_administrator_account_id`; it is
deliberately a single account.

## Account IDs and this public repository

`pbs-common/terraform-aws-vm-migration` is public and has never committed a real 12-digit
AWS account ID -- every ID in the tree is a `123456789012`-style placeholder. This
directory keeps that property: `delegated_administrator_account_id` has no default and is
absent from the committed `.tfvars`, so it must come from `TF_VAR_EXTRAS` or `-var`. A
missing value fails the plan rather than silently defaulting to the wrong account.
