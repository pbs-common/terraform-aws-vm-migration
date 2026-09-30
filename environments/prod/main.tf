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
    "aws:ec2launchtemplate:version"                = "5"
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
    "aws:ec2launchtemplate:version"                = "5"
  }
}

import {
  to = aws_instance.i_amsi01_pat1_w
  id = "i-0562129d8614d2825"
}