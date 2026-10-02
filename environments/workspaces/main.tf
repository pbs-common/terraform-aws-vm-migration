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