aws_region = "us-east-1"

# CloudWatch alerts: dev is NON-PROD tier, routine channel only, email to WinOpsDL.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
}

# Confirmed settled, nothing stuck in ALARM, before flipping this on.
cloudwatch_alarms_enabled = true

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "dev"
  "pbs:billing:product"     = "dev"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}

dso_topic_arn = "arn:aws:sns:us-east-1:600417784090:email-to-dso"
