output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.this.arn
}

output "backup_vault_id" {
  description = "ID of the backup vault"
  value       = aws_backup_vault.this.id
}

output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = aws_backup_vault.this.name
}
