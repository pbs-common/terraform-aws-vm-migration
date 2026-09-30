# Managed Prefix List Module

This module creates an AWS EC2 managed prefix list and its CIDR entries, for reuse across multiple security group rules instead of repeating the same CIDR blocks everywhere.

## Usage

```hcl
module "on_prem" {
  source = "./modules/managed-prefix-list"

  name        = "on-prem"
  max_entries = 2

  entries = [
    { cidr = "10.168.0.0/16", description = "soc" },
    { cidr = "10.68.50.0/24", description = "cchq" },
  ]

  tags = {
    Environment = "ad"
  }
}
```

Reference the resulting prefix list from a security group rule with `prefix_list_id = module.on_prem.id`.

## A note on quota

A security group rule that references a prefix list counts against the AWS rule quota for that security group by the prefix list's `max_entries`, not as a single rule. A prefix list sized for 20 entries still costs 20 rule slots on any security group that references it, even if only a few entries are populated. Size `max_entries` to what the list actually needs, not a rounder number "for headroom", or it will eat more quota than expected.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the managed prefix list | `string` | N/A | yes |
| max_entries | Maximum number of entries the prefix list can hold | `number` | N/A | yes |
| entries | CIDR entries for the prefix list | `list(object({ cidr = string, description = optional(string) }))` | `[]` | no |
| address_family | Address family of the prefix list, "IPv4" or "IPv6" | `string` | `"IPv4"` | no |
| tags | Tags applied to the prefix list, merged with an automatic Name tag | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | ID of the managed prefix list |
| arn | ARN of the managed prefix list |
| max_entries | Configured max_entries, also the exact number of security group rule slots any referencing rule will consume |
