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
    notifying everyone every time.

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
      topic_arn                 - ARN of an existing SNS topic to reuse instead of
                                   creating one. When set, this module skips creating
                                   a topic and skips managing any subscriptions on it
                                   (email/sms/Slack/Teams/PagerDuty settings above are
                                   ignored for this channel) - subscriptions are the
                                   owning module/account's responsibility.
  EOT
  type = map(object({
    email_subscriptions                  = optional(list(string), [])
    sms_subscriptions                    = optional(list(string), [])
    slack_webhook_secret_arn             = optional(string)
    teams_webhook_secret_arn             = optional(string)
    pagerduty_integration_key_secret_arn = optional(string)
    topic_arn                            = optional(string)
  }))
  default = {}
}

variable "sns_kms_key_arn" {
  description = "KMS key ARN to encrypt each SNS topic at rest. Null leaves it unencrypted -- alias/aws/sns blocks CloudWatch Alarms from publishing here, so a customer-managed key with that permission granted is required to turn encryption on."
  type        = string
  default     = null
}

variable "lambda_log_retention_days" {
  description = "Log retention, in days, for each webhook forwarder Lambda. Only matters for channels with a Slack or Teams webhook set."
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to resources, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}
