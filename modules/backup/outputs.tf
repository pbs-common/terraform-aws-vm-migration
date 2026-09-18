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

output "daily_plan_id" {
  description = "ID of the daily backup plan"
  value       = aws_backup_plan.daily.id
}

output "daily_plan_arn" {
  description = "ARN of the daily backup plan"
  value       = aws_backup_plan.daily.arn
}

output "weekly_plan_id" {
  description = "ID of the weekly backup plan"
  value       = aws_backup_plan.weekly.id
}

output "weekly_plan_arn" {
  description = "ARN of the weekly backup plan"
  value       = aws_backup_plan.weekly.arn
}
