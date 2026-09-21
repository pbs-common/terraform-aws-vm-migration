variable "vault_name" {
  description = "Name of the backup vault."
  type        = string

  validation {
    condition = (
      can(regex("^[0-9A-Za-z][0-9A-Za-z_.-]{1,49}$", var.vault_name)) &&
      length("${var.vault_name}-backup-service-role") <= 64 &&
      length("${var.vault_name}-daily-plan") <= 50 &&
      length("${var.vault_name}-daily-rule") <= 50 &&
      length("${var.vault_name}-weekly-plan") <= 50 &&
      length("${var.vault_name}-weekly-rule") <= 50 &&
      length("${var.vault_name}-daily-selection") <= 50 &&
      length("${var.vault_name}-weekly-selection") <= 50
    )
    error_message = "vault_name must be 2-50 characters of letters, numbers, periods, underscores, or hyphens, and must keep derived IAM role, backup plan, backup rule, and backup selection names within AWS length limits."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for backup encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "daily_schedule" {
  description = "Backup schedule for daily backups in cron expression format. Default is every day at midnight UTC."
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "daily_retention" {
  description = "Number of days to retain daily backups before deletion."
  type        = number
  default     = 14
}

variable "weekly_schedule" {
  description = "Backup schedule for weekly backups in cron expression format. Default is Saturday at midnight UTC."
  type        = string
  default     = "cron(0 0 ? * SAT *)"
}

variable "weekly_retention" {
  description = "Number of days to retain weekly backups before deletion."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags to apply to backup resources."
  type        = map(string)
  default     = {}
}
