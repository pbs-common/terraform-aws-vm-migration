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
    "i-0562129d8614d2825" = { ami = aws_instance.i_amsi01_pat1_w.ami, instance_type = aws_instance.i_amsi01_pat1_w.instance_type }
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

  name = "prod"

  notification_channels = var.cloudwatch_alerts_notification_channels

  alarms = local.cloudwatch_alerts_alarms

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