output "staging_subnet_id" {
  description = "ID of the MGN staging area subnet"
  value       = aws_subnet.mgn_staging.id
}

output "staging_subnet_cidr" {
  description = "CIDR block of the MGN staging area subnet"
  value       = aws_subnet.mgn_staging.cidr_block
}

output "mgn_staging_security_group_id" {
  description = "Security group ID for the staging subnet"
  value       = aws_security_group.mgn_staging.id
}

output "mgn_agent_security_group_id" {
  description = "Security group ID for MGN agents on source servers"
  value       = aws_security_group.mgn_agent.id
}

output "mgn_service_role_arn" {
  description = "ARN of the MGN service role"
  value       = aws_iam_role.mgn_service_role.arn
}

output "mgn_service_role_name" {
  description = "Name of the MGN service role"
  value       = aws_iam_role.mgn_service_role.name
}

output "mgn_agent_role_arn" {
  description = "ARN of the MGN agent execution role"
  value       = aws_iam_role.mgn_agent_role.arn
}

output "mgn_agent_instance_profile_name" {
  description = "Name of the IAM instance profile for MGN agents"
  value       = aws_iam_instance_profile.mgn_agent.name
}

output "mgn_agent_instance_profile_arn" {
  description = "ARN of the IAM instance profile for MGN agents"
  value       = aws_iam_instance_profile.mgn_agent.arn
}

output "mgn_cross_account_role_arn" {
  description = "ARN of the cross-account replication role (if configured)"
  value       = try(aws_iam_role.mgn_cross_account_role[0].arn, null)
}

output "mgn_replication_settings_parameter_name" {
  description = "SSM parameter name containing the default replication settings"
  value       = aws_ssm_parameter.mgn_replication_settings.name
}

output "internet_gateway_id" {
  description = "ID of the internet gateway for staging subnet outbound access"
  value       = var.create_internet_gateway ? aws_internet_gateway.mgn[0].id : var.internet_gateway_id
}

output "route_table_id" {
  description = "ID of the route table for staging subnet"
  value       = aws_route_table.mgn_staging.id
}

output "network_acl_id" {
  description = "ID of the network ACL for staging subnet"
  value       = aws_network_acl.mgn_staging.id
}

output "cloudwatch_log_group_replication" {
  description = "CloudWatch log group for replication"
  value       = aws_cloudwatch_log_group.mgn_replication.name
}

output "cloudwatch_log_group_agents" {
  description = "CloudWatch log group for agents"
  value       = aws_cloudwatch_log_group.mgn_agents.name
}
