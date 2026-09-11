# org-delegation

AWS Organizations delegation for AWS Application Migration Service (MGN), captured as code.

## What this manages

Two `aws_organizations_delegated_administrator` registrations, both delegated to
**pbs-sdo-shared-workspace** and anchored to the organization management account:

| Service principal | Why AWS Transform needs it | Live as of 2026-09-11 |
|---|---|---|
| `mgn.amazonaws.com` | Administer Application Migration Service from a member account | Registered by hand 2026-09-11 09:35:55 -04:00, **imported** by this code |
| `member.org.stacksets.cloudformation.amazonaws.com` | Transform deploys through StackSets with `CallAs: DELEGATED_ADMIN` | **Created by this code** on apply, 2026-09-11 10:03:05 -04:00 |

Both are live and ACTIVE. This directory has been applied.

**Both principals are required and `service_principals` enforces it.** Extras are
allowed, so a future Transform prerequisite needs no code change, but neither of these
two can be dropped. It is a validation rather than a convention because **both failure
modes are silent** -- neither produces an error, and the validation is the only thing
between a narrowed set and real damage:

| Narrowed to | Plan | Consequence |
|---|---|---|
| StackSets only | `1 to import, 0 to add`, exit 0 | MGN drops out of management: still registered in AWS, described by no code |
| MGN only | `0 to add, 0 to change, 1 to destroy`, exit 0 | The live StackSets delegation is **deregistered**, breaking Transform's deployments |

Found by Copilot review on this PR and confirmed by running both cases. Note the first
row used to fail loudly, because a static import block named MGN explicitly; moving to a
`for_each` import block removed that accidental guard, so the validation now carries it.

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

Applied 2026-09-11. State lives in the management account's existing Terraform state
bucket:

    bucket  pbs-master-tfstate
    key     terraform-aws-vm-migration/org-delegation.tfstate
    region  us-east-1

That bucket is versioned and SSE-AES256, and is the management account's established
state location -- it already holds `aws-organization-account-mgmt`,
`aws-organizations-non-negotiables`, `aws-entra-sso-groups/*` and similar. The key
follows its `<repo>/<component>.tfstate` convention.

This choice was made to get the StackSets delegation applied and is easy to revisit:
moving it means `terraform init -migrate-state` to a new bucket/key, with no change to
the live registrations.

## Applying

Credentials must be in the management account. pbs-login is the STS bastion --
`arn:aws:iam::<management account>:role/pbs-admin` trusts it, which is how this was
applied:

```console
aws sts assume-role \
  --role-arn arn:aws:iam::<management account>:role/pbs-admin \
  --role-session-name <your session> \
  --profile pbs-login/AdministratorAccess
# export the returned credentials, then:

export TF_VAR_delegated_administrator_account_id=<member account id>

terraform init \
  -backend-config="bucket=pbs-master-tfstate" \
  -backend-config="key=terraform-aws-vm-migration/org-delegation.tfstate" \
  -backend-config="region=us-east-1"

terraform plan -var-file org-delegation.tfvars
```

**A plan today should report no changes.** Both registrations are in state and live.

For the record, the first plan -- run before the apply -- reported **1 to import, 1 to
add, 0 to change, 0 to destroy**: MGN adopted, StackSets created. If a future plan wants
to add or destroy either registration, the live delegation has drifted from this code;
read the plan before applying it.

## Note: StackSets is delegated to other accounts too

`member.org.stacksets.cloudformation.amazonaws.com` was already registered to three other
accounts before this change -- pbs-ops-tools, pbs-security and pbs-logging -- and those
registrations are **not** managed here. AWS permits multiple StackSets delegated
administrators, so adding this account does not displace them, and this state file must
never be allowed to think it owns them.

If a future change needs to manage those too, add them as separate module instances,
each with its own `for_each` import block. Do not widen
`delegated_administrator_account_id`; it is deliberately a single account. And prefer a
`for_each` import block over several static ones in every case -- see the note in
`main.tf`: Terraform 1.16.0 silently honours only the first of several static import
blocks aimed at one `for_each` resource.

## Account IDs and this public repository

`pbs-common/terraform-aws-vm-migration` is public and has never committed a real 12-digit
AWS account ID -- every ID in the tree is a `123456789012`-style placeholder. This
directory keeps that property: `delegated_administrator_account_id` has no default and is
absent from the committed `.tfvars`. Supply it the way the worked example above does --
`export TF_VAR_delegated_administrator_account_id=<id>`, or `-var` -- and a missing value
fails the plan rather than silently defaulting to the wrong account.

Not via `TF_VAR_EXTRAS`: that secret is decoded into `TF_VAR_*` by the reusable
plan/apply workflows, and this directory deliberately has none, so nothing would decode
it and the variable would stay unset.
