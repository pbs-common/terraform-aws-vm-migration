output "delegated_administrator_account_id" {
  description = "Account ID registered as delegated administrator."
  value       = var.delegated_administrator_account_id
}

output "registrations" {
  description = "One entry per registered service principal, keyed by the principal."
  value = {
    for principal, reg in aws_organizations_delegated_administrator.this : principal => {
      arn                     = reg.arn
      name                    = reg.name
      status                  = reg.status
      delegation_enabled_date = reg.delegation_enabled_date
    }
  }
}

output "management_account_id" {
  description = "Management account the delegation is anchored to (the account this module must run in)."
  value       = data.aws_organizations_organization.this.master_account_id
}
