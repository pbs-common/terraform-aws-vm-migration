output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance, if associated."
  value       = aws_instance.this.public_ip
}

output "ami_id" {
  description = "AMI ID the instance was launched from. Marked sensitive only because Terraform propagates the sensitivity of the upstream SSM parameter data source through any attribute it touches - the value itself (an AMI ID) isn't secret."
  value       = aws_instance.this.ami
  sensitive   = true
}

output "security_group_id" {
  description = "ID of the security group created by this module, if any."
  value       = var.create_security_group ? aws_security_group.this[0].id : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role created by this module, if any."
  value       = var.create_iam_instance_profile ? aws_iam_role.this[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile attached to the instance."
  value       = local.iam_instance_profile_name
}

output "vpc_id" {
  description = "ID of the VPC the selected subnet belongs to."
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the private subnet the instance was placed in."
  value       = local.subnet_id
}
