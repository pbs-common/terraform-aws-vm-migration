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
    "pbs:billing:environment"                      = "Dev"
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
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Zheng-Dhong"
    "pbs:billing:product"                          = "Workstation"
  }
}

import {
  to = aws_instance.i_ng_ws_zc_t1_l
  id = "i-03d447ddfcf97efe7"
}