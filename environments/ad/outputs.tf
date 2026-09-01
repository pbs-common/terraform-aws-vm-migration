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
