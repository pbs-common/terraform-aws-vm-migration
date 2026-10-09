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

  name = "staging"

  notification_channels = local.cloudwatch_alerts_notification_channels

  # Same bucket as this account's Terraform state (see .github/workflows/staging.yaml). A
  # CI step uploads the webhook forwarder Lambda's zip here before plan/apply run.
  lambda_artifact_s3_bucket = "pbs-staging-terraform-state"

  tags = var.tags
}

resource "aws_instance" "esb_rtm01_qa" {
  ami           = "ami-09722327218b378f6"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-39400dc850bc703c8"
    "Name"                                         = "esb-rtm01-qa"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39c41340ab7ec7fe5"
    "mgn.amazonaws.com-source-server"              = "s-39400dc850bc703c8"
    "pbs:billing:environment"                      = "QA"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-39400dc850bc703c8"
    "Name"                                         = "esb-rtm01-qa"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39c41340ab7ec7fe5"
    "mgn.amazonaws.com-source-server"              = "s-39400dc850bc703c8"
    "pbs:billing:environment"                      = "QA"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.esb_rtm01_qa
  id = "i-05daff18817bf6938"
}

module "esb_rtm01_qa_alarms" {
  source = "../../modules/instance-alarms"

  environment   = "staging"
  instance_name = "esb-rtm01-qa"
  instance_id   = aws_instance.esb_rtm01_qa.id
  image_id      = aws_instance.esb_rtm01_qa.ami
  instance_type = aws_instance.esb_rtm01_qa.instance_type
  os_family     = "linux"
  disks = [
    { path = "/", device = "mapper/rhel-root", fstype = "xfs" },
    { label = "home", path = "/home", device = "mapper/rhel-home", fstype = "xfs" },
  ]

  routine_topic_arn  = module.cloudwatch_alerts.sns_topic_arns["routine"]
  critical_topic_arn = module.cloudwatch_alerts.sns_topic_arns["critical"]
  actions_enabled    = var.cloudwatch_alarms_enabled

  tags = var.tags
}
