output "id" {
  description = "ID of the managed prefix list."
  value       = aws_ec2_managed_prefix_list.this.id
}

output "arn" {
  description = "ARN of the managed prefix list."
  value       = aws_ec2_managed_prefix_list.this.arn
}

output "max_entries" {
  description = "Configured max_entries. Also the exact number of security group rule slots any rule referencing this list will consume."
  value       = aws_ec2_managed_prefix_list.this.max_entries
}
