variable "vault_name" {
  description = "Name of the backup vault."
  type        = string

  validation {
    condition = (
      can(regex("^[0-9A-Za-z_.-]{2,50}$", var.vault_name)) &&
      length("${var.vault_name}-backup-service-role") <= 64 &&
      length("${var.vault_name}-incremental-plan") <= 50 &&
      length("${var.vault_name}-incremental-rule") <= 50 &&
      length("${var.vault_name}-full-plan") <= 50 &&
      length("${var.vault_name}-full-rule") <= 50 &&
      length("${var.vault_name}-incremental-selection") <= 50 &&
      length("${var.vault_name}-full-selection") <= 50
    )
    error_message = "vault_name must be 2-50 characters of letters, numbers, periods, underscores, or hyphens, and must keep derived IAM role, backup plan, backup rule, and backup selection names within AWS length limits."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for backup encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "incremental_schedule" {
  description = "Backup schedule for incremental backups in cron expression format. Default is daily at midnight UTC."
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "incremental_retention_days" {
  description = "Number of days to retain incremental backups before deletion."
  type        = number
  default     = 14
}

variable "full_schedule" {
  description = "Backup schedule for full backups in cron expression format. Default is Saturday at midnight UTC."
  type        = string
  default     = "cron(0 0 ? * SAT *)"
}

variable "full_retention_days" {
  description = "Number of days to retain full backups before deletion."
  type        = number
  default     = 12
}

variable "tags" {
  description = "Tags to apply to backup resources."
  type        = map(string)
  default     = {}
}
