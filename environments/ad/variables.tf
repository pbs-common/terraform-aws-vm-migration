variable "aws_region" {
  description = "AWS region for the AD environment."
  type        = string
}

variable "private_subnet_name_prefix" {
  description = "Prefix of the Name tag on candidate private subnets for DC1/DC2 (e.g. \"pbs-sharedtools-useast1-subnet-private\"). Combined with each DC's availability zone to resolve a subnet via data source; the VPC ID is derived from it, never hardcoded."
  type        = string
}

variable "dc1_availability_zone" {
  description = "Availability zone for DC1. The module selects a private subnet in this AZ automatically."
  type        = string
}

variable "dc2_availability_zone" {
  description = "Availability zone for DC2. Should differ from dc1_availability_zone for availability."
  type        = string
}

variable "golden_ami_id" {
  description = "AMI ID of the golden image for DC1/DC2 (Windows Server + AD-Domain-Services/DNS features installed, sysprepped, not promoted). Built manually via console/SSM, not by Terraform. Required so DCs don't float onto whatever \"latest\" Windows AMI happens to resolve at apply time."
  type        = string

  validation {
    condition     = length(trimspace(var.golden_ami_id)) > 0
    error_message = "golden_ami_id must not be empty - build the golden AMI first and set its real ami-xxxxxxxx id here."
  }
}

variable "tags" {
  description = "Tags applied to resources, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "Instance type for DC1/DC2."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root volume size (GiB) for DC1/DC2."
  type        = number
  default     = 100
}

variable "ad_security_groups" {
  description = "Security groups for AD port access. Each top-level key becomes its own SG; each named group within it gets a dedicated managed prefix list, and every group gets identical access to all AD ports (including ADWS) on that SG. Group a set of CIDRs together when their combined size x port count fits under the per-SG rule quota; split into another top-level key otherwise."
  type = map(object({
    groups = map(list(string))
  }))
  default = {}

  validation {
    # A group name reused across two SGs silently overwrites the first one's CIDRs.
    condition = (
      length(flatten([for sg in var.ad_security_groups : keys(sg.groups)]))
      == length(distinct(flatten([for sg in var.ad_security_groups : keys(sg.groups)])))
    )
    error_message = "Group names must be unique across every ad_security_groups entry, not just within one SG."
  }
}

variable "key_name" {
  description = "Optional EC2 key pair name, kept as an RDP fallback alongside SSM Session Manager access."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for backup encryption. If null, AWS-managed encryption is used."
  type        = string
  default     = null
}

variable "backup_vault_name" {
  description = "Name of the backup vault."
  type        = string
  default     = "ad-backup-vault"
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

variable "cloudwatch_alerts_notification_channels" {
  description = "Notification channels for ad CloudWatch alerts, like \"routine\" or \"critical\". See modules/cloudwatch-alerts/variables.tf for the object shape."
  type = map(object({
    email_subscriptions       = optional(list(string), [])
    sms_subscriptions         = optional(list(string), [])
    slack_webhook_secret_arn  = optional(string)
    teams_webhook_secret_arn  = optional(string)
    pagerduty_integration_key = optional(string)
  }))
  default = {}
}

variable "cloudwatch_alerts_alarms" {
  description = "CloudWatch metric alarms for ad. See modules/cloudwatch-alerts/variables.tf for the object shape. Empty until real metrics are confirmed."
  type = list(object({
    name                 = string
    description          = optional(string)
    namespace            = string
    metric_name          = string
    statistic            = optional(string, "Average")
    period               = optional(number, 300)
    evaluation_periods   = optional(number, 1)
    datapoints_to_alarm  = optional(number)
    threshold            = number
    comparison_operator  = string
    dimensions           = optional(map(string), {})
    treat_missing_data   = optional(string, "missing")
    notify_ok            = optional(bool, true)
    notification_channel = string
  }))
  default = []
}
