output "policy_arn" {
  description = "ARN of the tag-scoped SSM session-access policy."
  value       = aws_iam_policy.this.arn
}

output "policy_name" {
  description = "Name of the tag-scoped SSM session-access policy."
  value       = aws_iam_policy.this.name
}
