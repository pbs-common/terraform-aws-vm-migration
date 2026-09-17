variable "vault_name" {
  description = "Name of the backup vault."
  type        = string

  validation {
    condition     = length(trimspace(var.vault_name)) > 0
    error_message = "vault_name must not be empty."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for backup encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "backup_schedule" {
  description = "Backup schedule in cron expression format. Default is daily at 1 AM UTC."
  type        = string
  default     = "cron(0 1 * * ? *)"
}

variable "backup_retention_days" {
  description = "Number of days to retain backups before deletion."
  type        = number
  default     = 30
}


variable "tags" {
  description = "Tags to apply to backup resources."
  type        = map(string)
  default     = {}
}
