aws_region = "us-east-1"

# CloudWatch alerts: staging is PROD tier. Two channels: routine (email, disk at 8%
# free) and critical (email, Slack, PagerDuty, for ping/service down and disk at 4%/0%
# free). Slack webhook secret and PagerDuty key are both live, by name only.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
  critical = {
    email_subscriptions                   = ["winopsdl@pbs.org"]
    slack_webhook_secret_name             = "staging-cloudwatch-alerts-slack-webhook"
    pagerduty_integration_key_secret_name = "staging-cloudwatch-alerts-pagerduty-key"
  }
}

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "staging"
  "pbs:billing:product"     = "staging"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}
