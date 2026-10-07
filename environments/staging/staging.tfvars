aws_region = "us-east-1"

# CloudWatch alerts: staging is PROD tier. Two channels: routine (email, disk at 8%
# free) and critical (email, Slack, PagerDuty, for ping/service down and disk at 4%/0%
# free). Slack webhook secret is live, PagerDuty key pending.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
  critical = {
    email_subscriptions      = ["winopsdl@pbs.org"]
    slack_webhook_secret_arn = "arn:aws:secretsmanager:us-east-1:395747404294:secret:staging-cloudwatch-alerts-slack-webhook-aifTEe"
    # pagerduty_integration_key pending
  }
}

# Alarms stay empty until there's a disk alarm written for pbsd-budget-uat.

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "staging"
  "pbs:billing:product"     = "staging"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}
