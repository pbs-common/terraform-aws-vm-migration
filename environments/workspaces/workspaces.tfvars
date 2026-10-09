aws_region = "us-east-1"

# CloudWatch alerts: workspaces is NON-PROD tier, routine channel only, email to WinOpsDL.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
}

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "workspaces"
  "pbs:billing:product"     = "workspaces"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}