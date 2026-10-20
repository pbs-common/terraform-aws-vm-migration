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

output "org_read_delegation_policy_arn" {
  description = "ARN of the organization resource policy delegating Organizations read access to the delegated administrator."
  value       = aws_organizations_resource_policy.org_read_delegation.arn
}

output "org_read_delegation_actions" {
  description = "Organizations actions delegated to the delegated administrator account."
  value       = local.org_read_delegation_actions
}
