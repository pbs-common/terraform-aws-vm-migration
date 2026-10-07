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
