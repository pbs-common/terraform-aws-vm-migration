# CloudWatch Alerts Module

This module creates named notification channels - each its own SNS topic with email/SMS/Slack/Teams/PagerDuty subscriptions - for CloudWatch alarms to route into. It does not create alarms itself; alarms are colocated with each instance by the `instance-alarms` module, which references this module's `sns_topic_arns` output directly.

## Usage

```hcl
module "cloudwatch_alerts" {
  source = "./modules/cloudwatch-alerts"

  name = "ad"

  notification_channels = {
    routine = {
      email_subscriptions = ["winopsdl@pbs.org"]
    }
    critical = {
      email_subscriptions      = ["winopsdl@pbs.org"]
      slack_webhook_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ad-slack-webhook-aBc123"
    }
  }

  # Only needed if any channel sets a Slack/Teams webhook - terraform apply zips and
  # uploads the forwarder Lambda's code here itself (see modules/cloudwatch-alerts/main.tf).
  lambda_artifact_s3_bucket = "pbs-ad-ds-terraform-state"

  tags = {
    Environment = "ad"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name | Name prefix for every resource this module creates, usually the environment name like "dev" or "prod". Keep it short (24 chars max): derived names add a channel key plus a suffix, and IAM role names cap at 64 characters. | `string` | n/a | yes |
| lambda_artifact_s3_bucket | S3 bucket holding the webhook forwarder Lambda's deployment package, zipped and uploaded during apply. Only required if a channel sets a Slack or Teams webhook. | `string` | `null` | no |
| lambda_artifact_s3_prefix | S3 key prefix for the webhook forwarder Lambda's deployment package in `lambda_artifact_s3_bucket`. The actual key is content-addressed (the source hash is appended), so concurrent runs for different commits never overwrite each other's upload. | `string` | `"cloudwatch-alerts"` | no |
| lambda_log_retention_days | Log retention, in days, for each webhook forwarder Lambda. Only matters for channels with a Slack or Teams webhook set. | `number` | `14` | no |
| notification_channels | Named notification channels, like "routine" or "critical", each its own SNS topic with its own subscriptions. Lets alarms route to different channels instead of notifying everyone every time. Per channel: `email_subscriptions` - email addresses subscribed directly, each confirms via the link AWS emails before alerts start. `sms_subscriptions` - phone numbers subscribed directly. `slack_webhook_secret_arn` - ARN of a Secrets Manager secret holding the Slack webhook URL, read by the Lambda forwarder at invoke time so the URL never touches Terraform state. `teams_webhook_secret_arn` - same, for Microsoft Teams. `pagerduty_integration_key_secret_arn` - ARN of a Secrets Manager secret holding the PagerDuty integration key, read at plan time and embedded directly in the SNS subscription endpoint (so unlike the webhook secrets, this one does end up in Terraform state). `topic_arn` - ARN of an existing SNS topic to reuse instead of creating one; when set, this module skips creating a topic and skips managing any subscriptions on it. | `map(object({...}))` | `{}` | no |
| sns_kms_key_arn | KMS key ARN to encrypt each SNS topic at rest. Null leaves it unencrypted - `alias/aws/sns` blocks CloudWatch Alarms from publishing here, so a customer-managed key with that permission granted is required to turn encryption on. | `string` | `null` | no |
| tags | Tags applied to resources, merged with an automatic Name tag. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| sns_topic_arns | Map of notification channel key to its SNS topic ARN. Point `alarm_actions`/`ok_actions` at one of these to notify through that channel. |
| webhook_forwarder_function_arns | Map of notification channel key to its webhook forwarder Lambda ARN, for channels that configured a Slack or Teams webhook. |
