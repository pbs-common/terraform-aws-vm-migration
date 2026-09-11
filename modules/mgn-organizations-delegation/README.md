# mgn-organizations-delegation

Registers one or more AWS Organizations service principals as delegated to a member
account. Written for AWS Application Migration Service (MGN) and AWS Transform, but the
resource is generic.

## Usage

```hcl
module "mgn_delegation" {
  source = "../../modules/mgn-organizations-delegation"

  delegated_administrator_account_id = var.delegated_administrator_account_id
  service_principals                 = ["mgn.amazonaws.com"]
}
```

## Must run in the management account

`RegisterDelegatedAdministrator` is a management-account-only call. The module reads
`aws_organizations_organization` and fails the plan with an explicit message if the
caller is not the management account, rather than surfacing an `AccessDeniedException`
partway through an apply.

## What it deliberately does not manage

**Organization trusted access.** The only Terraform resource expressing it is
`aws_organizations_organization`, which manages the entire organization -- adopting that
would place every other enabled service principal, and the organization itself, under
this state file. The module reads trusted access instead and asserts it is enabled for
each requested principal (`verify_trusted_access`, default `true`). Enable it separately:

```console
aws organizations enable-aws-service-access --service-principal mgn.amazonaws.com
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `delegated_administrator_account_id` | `string` | — | Member account to register. Validated as 12 digits. |
| `service_principals` | `set(string)` | `["mgn.amazonaws.com"]` | One registration per principal. |
| `verify_trusted_access` | `bool` | `true` | Assert trusted access is enabled before registering. |

## Outputs

| Name | Description |
|---|---|
| `delegated_administrator_account_id` | The account registered. |
| `registrations` | Per-principal `arn`, `name`, `status`, `delegation_enabled_date`. |
| `management_account_id` | Management account the delegation is anchored to. |

## Importing an existing registration

ID format is `<account_id>/<service_principal>`:

```hcl
import {
  to = module.mgn_delegation.aws_organizations_delegated_administrator.this["mgn.amazonaws.com"]
  id = "123456789012/mgn.amazonaws.com"
}
```

**Importing more than one principal? Use a single `for_each` import block, not one
static block each.** Measured on Terraform 1.16.0: of several static import blocks
targeting instances of the same `for_each` resource, only the **first** is honoured --
silently, with no error or warning, while the rest plan as `will be created` and then
fail on apply with `AccountAlreadyRegisteredException`. Correct on 1.14.6 and 1.15.8;
the `for_each` form below is correct on all three.

```hcl
import {
  for_each = var.service_principals

  to = module.mgn_delegation.aws_organizations_delegated_administrator.this[each.value]
  id = "${var.delegated_administrator_account_id}/${each.value}"
}
```
