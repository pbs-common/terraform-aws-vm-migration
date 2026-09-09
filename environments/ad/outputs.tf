output "dc1_instance_id" {
  description = "Instance ID of DC1."
  value       = module.dc1.instance_id
}

output "dc1_private_ip" {
  description = "Private IP address of DC1."
  value       = module.dc1.private_ip
}

output "dc2_instance_id" {
  description = "Instance ID of DC2."
  value       = module.dc2.instance_id
}

output "dc2_private_ip" {
  description = "Private IP address of DC2."
  value       = module.dc2.private_ip
}

output "ssm_session_access_policy_arn" {
  description = "ARN of the tag-scoped SSM session-access policy."
  value       = module.ssm_session_access.policy_arn
}

output "ssm_session_log_group_name" {
  description = "CloudWatch Log Group for SSM session logs. Point SSM-SessionManagerRunShell here."
  value       = aws_cloudwatch_log_group.ssm_sessions.name
}
