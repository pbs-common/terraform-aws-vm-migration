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
  default     = 90
}

variable "weekly_schedule" {
  description = "Backup schedule for weekly backups in cron expression format."
  type        = string
  default     = "cron(0 0 ? * SAT *)"
}

variable "weekly_retention" {
  description = "Number of days to retain weekly backups."
  type        = number
  default     = 90
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

variable "cloudwatch_alerts_notification_channels" {
  description = "Notification channels for workspaces CloudWatch alerts, like \"routine\" or \"critical\". See modules/cloudwatch-alerts/variables.tf for the object shape. workspaces is email-only - no Slack/PagerDuty fields, since this passes straight into the module with no name-to-ARN step to support them."
  type = map(object({
    email_subscriptions      = optional(list(string), [])
    sms_subscriptions        = optional(list(string), [])
    teams_webhook_secret_arn = optional(string)
    topic_arn                = optional(string)
  }))
  default = {}
}

variable "cloudwatch_alarms_enabled" {
  description = "Whether CloudWatch alarms notify on state change. Set false for an initial rollout so alarms settle into real state without firing, then flip to true once verified."
  type        = bool
  default     = false
}
