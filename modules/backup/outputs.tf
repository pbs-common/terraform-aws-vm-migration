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

output "incremental_plan_id" {
  description = "ID of the incremental backup plan"
  value       = aws_backup_plan.incremental.id
}

output "incremental_plan_arn" {
  description = "ARN of the incremental backup plan"
  value       = aws_backup_plan.incremental.arn
}

output "full_plan_id" {
  description = "ID of the full backup plan"
  value       = aws_backup_plan.full.id
}

output "full_plan_arn" {
  description = "ARN of the full backup plan"
  value       = aws_backup_plan.full.arn
}
