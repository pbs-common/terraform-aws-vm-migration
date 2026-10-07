aws_region = "us-east-1"

# CloudWatch alerts: prod is PROD tier. Two channels: routine (email, disk at 8%
# free) and critical (email, Slack, PagerDuty, for ping/service down and disk at 4%/0%
# free). Slack webhook secret is live, PagerDuty key pending.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
  critical = {
    email_subscriptions      = ["winopsdl@pbs.org"]
    slack_webhook_secret_arn = "arn:aws:secretsmanager:us-east-1:600417784090:secret:prod-cloudwatch-alerts-slack-webhook-9ww3w5"
    # pagerduty_integration_key pending
  }
}

# Disk alarms, primary disk per instance. 8% free routes to routine, 4%/0% free
# routes to critical, per the PROD-tier spec.
cloudwatch_alerts_alarms = [
  {
    name                 = "amsi01-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0562129d8614d2825", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "amsi01-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0562129d8614d2825", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "amsi01-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0562129d8614d2825", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
]

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "prod"
  "pbs:billing:product"     = "prod"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}