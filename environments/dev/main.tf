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

resource "aws_instance" "s_emts01_dat1_w" {
  ami           = "ami-0f534974106934085"
  instance_type = "m5.2xlarge"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3e6cb339dc9038f9d"
    "Name"                                         = "s-emts01-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3b391e544d4c43fff"
    "mgn.amazonaws.com-source-server"              = "s-3e6cb339dc9038f9d"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "Ready-API"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3e6cb339dc9038f9d"
    "Name"                                         = "s-emts01-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-3b391e544d4c43fff"
    "mgn.amazonaws.com-source-server"              = "s-3e6cb339dc9038f9d"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "Ready-API"
  }
}

import {
  to = aws_instance.s_emts01_dat1_w
  id = "i-0ef056ef9a04e2c6c"
}

resource "aws_instance" "s_emts03_dat1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.large"
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b0fbaba80b4589b8"
    "Name"                                         = "s-emts03-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-341fafe1f230a87dd"
    "mgn.amazonaws.com-source-server"              = "s-3b0fbaba80b4589b8"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "Ready-API"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-3b0fbaba80b4589b8"
    "Name"                                         = "s-emts03-dat1-w"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-341fafe1f230a87dd"
    "mgn.amazonaws.com-source-server"              = "s-3b0fbaba80b4589b8"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Poonam-Singh"
    "pbs:billing:product"                          = "Ready-API"
  }
}

import {
  to = aws_instance.s_emts03_dat1_w
  id = "i-04cf9c488ce8c1a1e"
}

resource "aws_security_group" "sbap01_sonarqube" {
  name_prefix = "sbap01-sonarqube-"
  description = "Dedicated SG for s-sbap01-dat1-x (SonarQube) application access"
  vpc_id      = "vpc-00f9a248160c17a5f"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "sbap01_sonarqube_9000" {
  security_group_id = aws_security_group.sbap01_sonarqube.id
  description       = "SonarQube web UI"
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-9000" })
}