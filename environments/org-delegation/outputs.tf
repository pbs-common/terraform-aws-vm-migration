output "delegated_administrator_account_id" {
  description = "Account registered as delegated administrator for every principal in service_principals (MGN and CloudFormation StackSets)."
  value       = module.mgn_delegation.delegated_administrator_account_id
}

output "management_account_id" {
  description = "Management account the delegation is anchored to."
  value       = module.mgn_delegation.management_account_id
}

output "registrations" {
  description = "Live registration detail per service principal."
  value       = module.mgn_delegation.registrations
}
