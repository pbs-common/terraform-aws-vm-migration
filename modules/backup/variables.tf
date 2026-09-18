variable "vault_name" {
  description = "Name of the backup vault."
  type        = string

  validation {
    condition     = length(trimspace(var.vault_name)) > 0 && length("${var.vault_name}-backup-service-role") <= 64
    error_message = "vault_name must not be empty and must keep derived IAM role name within 64 character limit."
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

variable "daily_retention_days" {
  description = "Number of days to retain daily backups before deletion."
  type        = number
  default     = 14
}

variable "weekly_schedule" {
  description = "Backup schedule for weekly backups in cron expression format. Default is Saturday at midnight UTC."
  type        = string
  default     = "cron(0 0 ? * SAT *)"
}

variable "weekly_retention_days" {
  description = "Number of days to retain weekly backups before deletion."
  type        = number
  default     = 12
}

variable "tags" {
  description = "Tags to apply to backup resources."
  type        = map(string)
  default     = {}
}
