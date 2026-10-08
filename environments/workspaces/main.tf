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
  for_each = toset([
    "AWSApplicationMigrationLaunchInstanceWithSsmRole",
    "AmazonSSMRoleForInstancesQuickSetup",
  ])

  role       = each.value
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
    "i-062c6c56e0ea43a52" = { ami = aws_instance.s_ghsd01_dat1_w.ami, instance_type = aws_instance.s_ghsd01_dat1_w.instance_type }
    "i-0f15f3836d730abb6" = { ami = aws_instance.s_sits01_dat1_x.ami, instance_type = aws_instance.s_sits01_dat1_x.instance_type }
    "i-0745c6a50a22b3970" = { ami = aws_instance.esdev_10.ami, instance_type = aws_instance.esdev_10.instance_type }
    "i-05358ac8ae6ae3398" = { ami = aws_instance.i_ng_ws_kt_t1_w.ami, instance_type = aws_instance.i_ng_ws_kt_t1_w.instance_type }
    "i-0e71029bbc740a4b2" = { ami = aws_instance.esdev_brian.ami, instance_type = aws_instance.esdev_brian.instance_type }
    "i-03cd76dd517b2efb6" = { ami = aws_instance.i_ng_ws_sm_t1_w.ami, instance_type = aws_instance.i_ng_ws_sm_t1_w.instance_type }
    "i-037e76172f90efc2d" = { ami = aws_instance.i_ng_ws_bb_t1_w.ami, instance_type = aws_instance.i_ng_ws_bb_t1_w.instance_type }
    "i-03d447ddfcf97efe7" = { ami = aws_instance.i_ng_ws_zc_t1_l.ami, instance_type = aws_instance.i_ng_ws_zc_t1_l.instance_type }
    "i-031ddd298cf491c67" = { ami = aws_instance.s_ghsd04_dat1_x.ami, instance_type = aws_instance.s_ghsd04_dat1_x.instance_type }
    "i-0882b12d32667c7ee" = { ami = aws_instance.i_ng_ws_mr_t1_w.ami, instance_type = aws_instance.i_ng_ws_mr_t1_w.instance_type }
    "i-069a3f4cdaec8c82a" = { ami = aws_instance.i_ng_ws_ld_t1_w.ami, instance_type = aws_instance.i_ng_ws_ld_t1_w.instance_type }
    "i-078edb8241c6df4f2" = { ami = aws_instance.esdev_12.ami, instance_type = aws_instance.esdev_12.instance_type }
    "i-0c2fd56636c99ff1d" = { ami = aws_instance.esdev_08.ami, instance_type = aws_instance.esdev_08.instance_type }
    "i-00c1e14ce9114b57c" = { ami = aws_instance.s_si_d1_t1_w.ami, instance_type = aws_instance.s_si_d1_t1_w.instance_type }
    "i-02913429a0e270b18" = { ami = aws_instance.esdev_chex.ami, instance_type = aws_instance.esdev_chex.instance_type }
    "i-0d9ab8addd6e1a4db" = { ami = aws_instance.devops_app1_dev.ami, instance_type = aws_instance.devops_app1_dev.instance_type }
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

  name = "workspaces"

  notification_channels = var.cloudwatch_alerts_notification_channels

  alarms = local.cloudwatch_alerts_alarms

  tags = var.tags
}
# Migrated instances from MGN
resource "aws_instance" "i_ng_ws_zc_t1_l" {
  ami           = "ami-0b84981f84c45e189"
  instance_type = "m5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-378ee4e9007b8f159"
    "Name"                                         = "i-ng-ws-zc-t1-l"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3fc50c58093c83b9e"
    "mgn.amazonaws.com-source-server"              = "s-378ee4e9007b8f159"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Zheng-Dhong"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-378ee4e9007b8f159"
    "Name"                                         = "i-ng-ws-zc-t1-l"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3fc50c58093c83b9e"
    "mgn.amazonaws.com-source-server"              = "s-378ee4e9007b8f159"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Zheng-Dhong"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_zc_t1_l
  id = "i-03d447ddfcf97efe7"
}

resource "aws_instance" "s_ghsd01_dat1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-369955e3abd2ae164"
    "Name"                                         = "s-ghsd01-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39e20ff37530c8126"
    "mgn.amazonaws.com-source-server"              = "s-369955e3abd2ae164"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "GitHub-Runner"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-369955e3abd2ae164"
    "Name"                                         = "s-ghsd01-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39e20ff37530c8126"
    "mgn.amazonaws.com-source-server"              = "s-369955e3abd2ae164"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "GitHub-Runner"
  }
}

import {
  to = aws_instance.s_ghsd01_dat1_w
  id = "i-062c6c56e0ea43a52"
}

resource "aws_instance" "s_sits01_dat1_x" {
  ami           = "ami-0cd015083896391d5"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3592534d8585fb9de"
    "Name"                                         = "s-sits01-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-32b1cec7dbbb82f22"
    "mgn.amazonaws.com-source-server"              = "s-3592534d8585fb9de"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3592534d8585fb9de"
    "Name"                                         = "s-sits01-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-32b1cec7dbbb82f22"
    "mgn.amazonaws.com-source-server"              = "s-3592534d8585fb9de"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.s_sits01_dat1_x
  id = "i-0f15f3836d730abb6"
}

resource "aws_instance" "i_ng_ws_sm_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b7f5c65de6e54418"
    "Name"                                         = "i-ng-ws-sm-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-35a9754289adeaee3"
    "mgn.amazonaws.com-source-server"              = "s-3b7f5c65de6e54418"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Sakthi-Madhappan"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = { "AWSApplicationMigrationServiceManaged" = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b7f5c65de6e54418"
    "Name"                                         = "i-ng-ws-sm-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-35a9754289adeaee3"
    "mgn.amazonaws.com-source-server"              = "s-3b7f5c65de6e54418"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Sakthi-Madhappan"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_sm_t1_w
  id = "i-03cd76dd517b2efb6"
}

resource "aws_instance" "i_ng_ws_bb_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3714e9ba8a9a3d67e"
    "Name"                                         = "i-ng-ws-bb-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-399e6b2275742138c"
    "mgn.amazonaws.com-source-server"              = "s-3714e9ba8a9a3d67e"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3714e9ba8a9a3d67e"
    "Name"                                         = "i-ng-ws-bb-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-399e6b2275742138c"
    "mgn.amazonaws.com-source-server"              = "s-3714e9ba8a9a3d67e"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_bb_t1_w
  id = "i-037e76172f90efc2d"
}

resource "aws_instance" "i_ng_ws_kt_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r7i.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-320dc6efe7f3429e6"
    "Name"                                         = "i-ng-ws-kt-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-315d9cc3cfcdd8018"
    "mgn.amazonaws.com-source-server"              = "s-320dc6efe7f3429e6"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-320dc6efe7f3429e6"
    "Name"                                         = "i-ng-ws-kt-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-315d9cc3cfcdd8018"
    "mgn.amazonaws.com-source-server"              = "s-320dc6efe7f3429e6"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_kt_t1_w
  id = "i-05358ac8ae6ae3398"
}

resource "aws_instance" "devops_app1_dev" {
  ami           = "ami-0f534974106934085"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3c61eb947c74d34b9"
    "Name"                                         = "devops-app1-dev"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3c9dcb63339ee5e11"
    "mgn.amazonaws.com-source-server"              = "s-3c61eb947c74d34b9"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3c61eb947c74d34b9"
    "Name"                                         = "devops-app1-dev"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3c9dcb63339ee5e11"
    "mgn.amazonaws.com-source-server"              = "s-3c61eb947c74d34b9"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.devops_app1_dev
  id = "i-0d9ab8addd6e1a4db"
}

resource "aws_instance" "esdev_brian" {
  ami           = "ami-0f534974106934085"
  instance_type = "m5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3da41592999f87bc9"
    "Name"                                         = "ESDEV-BRIAN"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-33ce31344ac32ecb8"
    "mgn.amazonaws.com-source-server"              = "s-3da41592999f87bc9"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3da41592999f87bc9"
    "Name"                                         = "ESDEV-BRIAN"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-33ce31344ac32ecb8"
    "mgn.amazonaws.com-source-server"              = "s-3da41592999f87bc9"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.esdev_brian
  id = "i-0e71029bbc740a4b2"
}

resource "aws_instance" "esdev_chex" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b9cee0d43ee0e8b4"
    "Name"                                         = "ESDEV-CHEX"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-33ce31344ac32ecb8"
    "mgn.amazonaws.com-source-server"              = "s-3b9cee0d43ee0e8b4"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b9cee0d43ee0e8b4"
    "Name"                                         = "ESDEV-CHEX"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-33ce31344ac32ecb8"
    "mgn.amazonaws.com-source-server"              = "s-3b9cee0d43ee0e8b4"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.esdev_chex
  id = "i-02913429a0e270b18"
}

resource "aws_instance" "s_si_d1_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3fc69ea2f60bc8b92"
    "Name"                                         = "s-si-d1-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-31d091482f364113d"
    "mgn.amazonaws.com-source-server"              = "s-3fc69ea2f60bc8b92"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3fc69ea2f60bc8b92"
    "Name"                                         = "s-si-d1-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-31d091482f364113d"
    "mgn.amazonaws.com-source-server"              = "s-3fc69ea2f60bc8b92"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.s_si_d1_t1_w
  id = "i-00c1e14ce9114b57c"
}

resource "aws_instance" "s_ghsd04_dat1_x" {
  ami           = "ami-0571d6636d4767842"
  instance_type = "m5.2xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-37a34f38f9fc5d0b8"
    "Name"                                         = "s-ghsd04-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3f341ac4d4e9b77eb"
    "mgn.amazonaws.com-source-server"              = "s-37a34f38f9fc5d0b8"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-37a34f38f9fc5d0b8"
    "Name"                                         = "s-ghsd04-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3f341ac4d4e9b77eb"
    "mgn.amazonaws.com-source-server"              = "s-37a34f38f9fc5d0b8"
  }
}

import {
  to = aws_instance.s_ghsd04_dat1_x
  id = "i-031ddd298cf491c67"
}

resource "aws_instance" "esdev_10" {
  ami           = "ami-0f534974106934085"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3f492253f6eda0718"
    "Name"                                         = "ESDEV-10"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3f492253f6eda0718"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3f492253f6eda0718"
    "Name"                                         = "ESDEV-10"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3f492253f6eda0718"
  }
}

import {
  to = aws_instance.esdev_10
  id = "i-0745c6a50a22b3970"
}

resource "aws_instance" "i_ng_ws_mr_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r7i.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-36b77c24492f3595f"
    "Name"                                         = "i-ng-ws-mr-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-32a4dc4269435a410"
    "mgn.amazonaws.com-source-server"              = "s-36b77c24492f3595f"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-36b77c24492f3595f"
    "Name"                                         = "i-ng-ws-mr-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-32a4dc4269435a410"
    "mgn.amazonaws.com-source-server"              = "s-36b77c24492f3595f"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_mr_t1_w
  id = "i-0882b12d32667c7ee"
}

resource "aws_instance" "i_ng_ws_ld_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r7i.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3a08db6b9601aa5a1"
    "Name"                                         = "i-ng-ws-ld-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3579b1f65eef0449d"
    "mgn.amazonaws.com-source-server"              = "s-3a08db6b9601aa5a1"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3a08db6b9601aa5a1"
    "Name"                                         = "i-ng-ws-ld-t1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3579b1f65eef0449d"
    "mgn.amazonaws.com-source-server"              = "s-3a08db6b9601aa5a1"
    "pbs:billing:environment"                      = "workspaces"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_ld_t1_w
  id = "i-069a3f4cdaec8c82a"
}

resource "aws_instance" "esdev_12" {
  ami           = "ami-0f534974106934085"
  instance_type = "r5.xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3352af1ee8a8d1876"
    "Name"                                         = "ESDEV-12"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3352af1ee8a8d1876"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3352af1ee8a8d1876"
    "Name"                                         = "ESDEV-12"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3352af1ee8a8d1876"
  }
}

import {
  to = aws_instance.esdev_12
  id = "i-078edb8241c6df4f2"
}

resource "aws_instance" "esdev_08" {
  ami           = "ami-0f534974106934085"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3c06f4b0f9abb3d09"
    "Name"                                         = "ESDEV-08"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3c06f4b0f9abb3d09"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3c06f4b0f9abb3d09"
    "Name"                                         = "ESDEV-08"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-371a5c53832ed4209"
    "mgn.amazonaws.com-source-server"              = "s-3c06f4b0f9abb3d09"
  }
}

import {
  to = aws_instance.esdev_08
  id = "i-0c2fd56636c99ff1d"
}