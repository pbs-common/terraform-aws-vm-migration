variable "name" {
  description = "Name prefix for every resource this module creates, usually the environment name like \"dev\" or \"prod\". Keep it short (24 chars max): derived names add a channel key plus a suffix, and IAM role names cap at 64 characters."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,24}$", var.name))
    error_message = "name must be 1-24 characters of letters, numbers, underscores, or hyphens."
  }
}

variable "notification_channels" {
  description = <<-EOT
    Named notification channels, like "routine" or "critical", each its own SNS topic
    with its own subscriptions. Lets alarms route to different channels instead of
    notifying everyone every time. Each alarm in `alarms` picks one channel by name.

    Per channel:
      email_subscriptions       - email addresses subscribed directly. Each one has to
                                   confirm via the link AWS emails them before alerts start.
      sms_subscriptions         - phone numbers subscribed directly, just a text, no
                                   on-call schedule or escalation.
      slack_webhook_secret_arn  - ARN of a Secrets Manager secret holding the Slack
                                   webhook URL, managed outside Terraform (synced from
                                   1Password). The Lambda forwarder reads it at invoke
                                   time, so the URL never touches Terraform state.
      teams_webhook_secret_arn  - same, for a Microsoft Teams webhook.
      pagerduty_integration_key_secret_arn - ARN of a Secrets Manager secret holding
                                   the PagerDuty integration key. Read at plan time
                                   (not by a Lambda, unlike the webhooks above) since
                                   it has to be embedded directly in the SNS
                                   subscription's endpoint URL. That means, unlike the
                                   webhook secrets, the key value does end up in
                                   Terraform state either way. Subscribes PagerDuty's
                                   endpoint directly over HTTPS, no Lambda needed, it
                                   auto-confirms.
  EOT
  type = map(object({
    email_subscriptions                  = optional(list(string), [])
    sms_subscriptions                    = optional(list(string), [])
    slack_webhook_secret_arn             = optional(string)
    teams_webhook_secret_arn             = optional(string)
    pagerduty_integration_key_secret_arn = optional(string)
  }))
  default = {}
}

variable "sns_kms_key_arn" {
  description = "KMS key ARN to encrypt each SNS topic at rest. Null uses the AWS-managed alias/aws/sns key."
  type        = string
  default     = null
}

variable "lambda_log_retention_days" {
  description = "Log retention, in days, for each webhook forwarder Lambda. Only matters for channels with a Slack or Teams webhook set."
  type        = number
  default     = 14
}

variable "alarms" {
  description = "CloudWatch metric alarms to create. Each one notifies, and clears unless notify_ok is false, through one channel in notification_channels. Leave empty until real thresholds are ready."
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

  validation {
    condition     = length(var.alarms) == length(distinct([for a in var.alarms : a.name]))
    error_message = "Each entry in alarms must have a unique name."
  }

  validation {
    condition     = alltrue([for a in var.alarms : contains(keys(var.notification_channels), a.notification_channel)])
    error_message = "Each alarm's notification_channel must be a key defined in notification_channels."
  }
}

variable "tags" {
  description = "Tags applied to resources, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}
