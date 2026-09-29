variable "aws_region" {
  description = "AWS region for the workspaces environment."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for backup encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "backup_vault_name" {
  description = "Name of the backup vault."
  type        = string
  default     = "workspaces-backup-vault"
}

variable "daily_schedule" {
  description = "Backup schedule for daily backups in cron expression format."
  type        = string
  default     = "cron(0 0 * * ? *)"
}

variable "daily_retention" {
  description = "Number of days to retain daily backups."
  type        = number
  default     = 14
}

variable "weekly_schedule" {
  description = "Backup schedule for weekly backups in cron expression format."
  type        = string
  default     = "cron(0 0 ? * SAT *)"
}

variable "weekly_retention" {
  description = "Number of days to retain weekly backups."
  type        = number
  default     = 14
}

variable "windows_vss" {
  description = "Enable Windows VSS for backups. Set to 'enabled' to enable."
  type        = string
  default     = "disabled"
}

variable "tags" {
  description = "Tags applied to resources, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}
