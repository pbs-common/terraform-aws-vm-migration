locals {
  entries_by_cidr = { for e in var.entries : e.cidr => e }
}

resource "aws_ec2_managed_prefix_list" "this" {
  name           = var.name
  address_family = var.address_family
  max_entries    = var.max_entries

  tags = merge(var.tags, { Name = var.name })

  # Entries managed via aws_ec2_managed_prefix_list_entry below, not inline.
  lifecycle {
    ignore_changes = [entry]
  }
}

resource "aws_ec2_managed_prefix_list_entry" "this" {
  for_each = local.entries_by_cidr

  prefix_list_id = aws_ec2_managed_prefix_list.this.id
  cidr           = each.value.cidr
  description    = each.value.description
}
