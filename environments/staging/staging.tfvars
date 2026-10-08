aws_region = "us-east-1"

# CloudWatch alerts: staging is PROD tier. Two channels: routine (email, disk at 8%
# free) and critical (email, Slack, PagerDuty, for ping/service down and disk at 4%/0%
# free). Slack webhook secret and PagerDuty key are both live.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
  critical = {
    email_subscriptions                  = ["winopsdl@pbs.org"]
    slack_webhook_secret_arn             = "arn:aws:secretsmanager:us-east-1:395747404294:secret:staging-cloudwatch-alerts-slack-webhook-aifTEe"
    pagerduty_integration_key_secret_arn = "arn:aws:secretsmanager:us-east-1:395747404294:secret:staging-cloudwatch-alerts-pagerduty-key-r8kQh6"
  }
}

# esb-rtm01-qa disk alarms. Linux: disk_used_percent, alarm high.
cloudwatch_alerts_alarms = [
  {
    name                 = "esb-rtm01-qa-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esb-rtm01-qa-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "esb-rtm01-qa-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  # esb-rtm01-qa also has a real /home volume, separate from /.
  {
    name                 = "esb-rtm01-qa-home-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esb-rtm01-qa-home-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "esb-rtm01-qa-home-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-05daff18817bf6938", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  # Reachability (ping) alarm. EC2 status check, no agent needed.
  {
    name                 = "esb-rtm01-qa-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed"
    dimensions           = { InstanceId = "i-05daff18817bf6938" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
]

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "staging"
  "pbs:billing:product"     = "staging"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}
