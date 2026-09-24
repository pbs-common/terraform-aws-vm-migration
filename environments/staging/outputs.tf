output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = module.backup.backup_vault_arn
}

output "backup_vault_id" {
  description = "ID of the backup vault"
  value       = module.backup.backup_vault_id
}

output "backup_vault_name" {
  description = "Name of the backup vault"
  value       = module.backup.backup_vault_name
}

output "daily_plan_id" {
  description = "ID of the daily backup plan"
  value       = module.backup.daily_plan_id
}

output "daily_plan_arn" {
  description = "ARN of the daily backup plan"
  value       = module.backup.daily_plan_arn
}

output "weekly_plan_id" {
  description = "ID of the weekly backup plan"
  value       = module.backup.weekly_plan_id
}

output "weekly_plan_arn" {
  description = "ARN of the weekly backup plan"
  value       = module.backup.weekly_plan_arn
}
