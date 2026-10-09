module "backup" {
  source = "../../modules/backup"

  vault_name  = var.backup_vault_name
  kms_key_arn = var.kms_key_arn

  daily_schedule  = var.daily_schedule
  daily_retention = var.daily_retention

  weekly_schedule  = var.weekly_schedule
  weekly_retention = var.weekly_retention

  windows_vss = var.windows_vss

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = "AWSApplicationMigrationLaunchInstanceWithSsmRole"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Covers instances adopted from MGN via import, which never call ec2-workload
# and so never get its per-instance association.
resource "aws_ssm_association" "cloudwatch_agent" {
  name = "AWSQuickSetupType-InstallAndManageCloudWatchAgent"

  targets {
    key    = "tag-key"
    values = ["AWSApplicationMigrationServiceSourceServerID"]
  }

  parameters = {
    isInstall                     = "true"
    isConfigure                   = "true"
    optionalConfigurationSource   = "default"
    optionalConfigurationLocation = ""
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cloudwatch_agent]
}

data "aws_caller_identity" "current" {}

# Looks up the real ARN (with its random suffix) so the webhook Lambda's IAM policy matches it.
data "aws_secretsmanager_secret" "slack_webhook" {
  for_each = {
    for key, channel in var.cloudwatch_alerts_notification_channels : key => channel
    if channel.slack_webhook_secret_name != null
  }

  name = each.value.slack_webhook_secret_name
}

locals {
  # Hold notifications until alarms settle after the first real apply.
  cloudwatch_alarms_enabled = false

  cloudwatch_alerts_notification_channels = {
    for key, channel in var.cloudwatch_alerts_notification_channels : key => merge(channel, {
      slack_webhook_secret_arn = (
        channel.slack_webhook_secret_name != null
        ? data.aws_secretsmanager_secret.slack_webhook[key].arn
        : null
      )
      # Read directly by Terraform, not IAM-matched, so the suffix-less ARN is fine here.
      pagerduty_integration_key_secret_arn = (
        channel.pagerduty_integration_key_secret_name != null
        ? "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${channel.pagerduty_integration_key_secret_name}"
        : null
      )
    })
  }
}

module "cloudwatch_alerts" {
  source = "../../modules/cloudwatch-alerts"

  name = "prod"

  notification_channels = local.cloudwatch_alerts_notification_channels

  tags = var.tags
}

module "amsi01_alarms" {
  source = "../../modules/instance-alarms"

  environment   = "prod"
  instance_name = "amsi01"
  instance_id   = aws_instance.i_amsi01_pat1_w.id
  image_id      = aws_instance.i_amsi01_pat1_w.ami
  instance_type = aws_instance.i_amsi01_pat1_w.instance_type
  os_family     = "windows"
  disks         = [{ drive_letter = "C:" }]

  routine_topic_arn  = module.cloudwatch_alerts.sns_topic_arns["routine"]
  critical_topic_arn = module.cloudwatch_alerts.sns_topic_arns["critical"]
  actions_enabled    = local.cloudwatch_alarms_enabled

  tags = var.tags
}
resource "aws_instance" "i_amsi01_pat1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-34502147e62820de6"
    "Name"                                         = "i-amsi01-pat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3ac2d9b8ebaa9b4dd"
    "mgn.amazonaws.com-source-server"              = "s-34502147e62820de6"
    "pbs:billing:environment"                      = "Prod"
    "pbs:billing:owner"                            = "Sherri-Ann"
    "pbs:billing:product"                          = "AlertMedia"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-34502147e62820de6"
    "Name"                                         = "i-amsi01-pat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3ac2d9b8ebaa9b4dd"
    "mgn.amazonaws.com-source-server"              = "s-34502147e62820de6"
    "pbs:billing:environment"                      = "Prod"
    "pbs:billing:owner"                            = "Sherri-Ann"
    "pbs:billing:product"                          = "AlertMedia"
  }
}

import {
  to = aws_instance.i_amsi01_pat1_w
  id = "i-0562129d8614d2825"
}