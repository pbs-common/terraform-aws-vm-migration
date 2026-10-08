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

locals {
  # ami/instance_type per managed instance, merged into CWAgent alarm dimensions
  # below so they can't go stale after a resize or replacement.
  instance_identity = {
    "i-05daff18817bf6938" = { ami = aws_instance.esb_rtm01_qa.ami, instance_type = aws_instance.esb_rtm01_qa.instance_type }
  }

  cloudwatch_alerts_alarms = [
    for alarm in var.cloudwatch_alerts_alarms : alarm.namespace == "CWAgent" ? merge(alarm, {
      dimensions = merge(alarm.dimensions, {
        ImageId      = local.instance_identity[alarm.dimensions.InstanceId].ami
        InstanceType = local.instance_identity[alarm.dimensions.InstanceId].instance_type
      })
    }) : alarm
  ]
}

module "cloudwatch_alerts" {
  source = "../../modules/cloudwatch-alerts"

  name = "staging"

  notification_channels = var.cloudwatch_alerts_notification_channels

  alarms = local.cloudwatch_alerts_alarms

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
