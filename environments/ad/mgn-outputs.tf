# MGN Replication Baseline Outputs

output "mgn_staging_subnet_id" {
  description = "ID of the MGN staging area subnet"
  value       = module.mgn_replication_baseline.staging_subnet_id
}

output "mgn_staging_subnet_cidr" {
  description = "CIDR block of the MGN staging area subnet"
  value       = module.mgn_replication_baseline.staging_subnet_cidr
}

output "mgn_staging_security_group_id" {
  description = "Security group ID for the MGN staging subnet"
  value       = module.mgn_replication_baseline.mgn_staging_security_group_id
}

output "mgn_agent_security_group_id" {
  description = "Security group ID for MGN agents on source servers"
  value       = module.mgn_replication_baseline.mgn_agent_security_group_id
}

output "mgn_service_role_arn" {
  description = "ARN of the MGN service role"
  value       = module.mgn_replication_baseline.mgn_service_role_arn
}

output "mgn_service_role_name" {
  description = "Name of the MGN service role"
  value       = module.mgn_replication_baseline.mgn_service_role_name
}

output "mgn_agent_role_arn" {
  description = "ARN of the MGN agent execution role"
  value       = module.mgn_replication_baseline.mgn_agent_role_arn
}

output "mgn_agent_instance_profile_name" {
  description = "Name of the IAM instance profile for MGN agents"
  value       = module.mgn_replication_baseline.mgn_agent_instance_profile_name
}

output "mgn_cross_account_role_arn" {
  description = "ARN of the cross-account replication role (if configured)"
  value       = module.mgn_replication_baseline.mgn_cross_account_role_arn
}

output "mgn_replication_settings_parameter_name" {
  description = "SSM parameter name containing the default replication settings template"
  value       = module.mgn_replication_baseline.mgn_replication_settings_parameter_name
}
