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
  description       = "SonarQube web UI, on-prem"
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.164.0.0/16"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-9000" })
}

resource "aws_vpc_security_group_ingress_rule" "sbap01_sonarqube_9000_aws" {
  security_group_id = aws_security_group.sbap01_sonarqube.id
  description       = "SonarQube web UI, ghsd04 CI runner"
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.202.0.0/16"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-9000-aws" })
}

resource "aws_vpc_security_group_ingress_rule" "sbap01_sonarqube_22" {
  security_group_id = aws_security_group.sbap01_sonarqube.id
  description       = "SSH"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.164.0.0/16"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-22" })
}

resource "aws_vpc_security_group_ingress_rule" "sbap01_sonarqube_443" {
  security_group_id = aws_security_group.sbap01_sonarqube.id
  description       = "HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.164.0.0/16"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-443" })
}

resource "aws_vpc_security_group_ingress_rule" "sbap01_sonarqube_3389" {
  security_group_id = aws_security_group.sbap01_sonarqube.id
  description       = "RDP"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.164.0.0/16"

  tags = merge(var.tags, { Name = "sbap01-sonarqube-3389" })
}

resource "aws_instance" "s_sbap01_dat1_x" {
  ami           = "ami-0447a785619664547"
  instance_type = "r5.large"
  vpc_security_group_ids = [
    aws_security_group.sbap01_sonarqube.id,
    "sg-01088e3be56d47a72",
  ]
  tags = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-306129d7833208c43"
    "Name"                                         = "s-sbap01-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39405a010ca796545"
    "mgn.amazonaws.com-source-server"              = "s-306129d7833208c43"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "SnoarQube"
  }
  tags_all = {
    "AWSApplicationMigrationServiceManaged"        = "mgn.amazonaws.com"
    "AWSApplicationMigrationServiceSourceServerID" = "s-306129d7833208c43"
    "Name"                                         = "s-sbap01-dat1-x"
    "map-migrated"                                 = "mig5T578AWUOW"
    "mgn.amazonaws.com-job"                        = "mgnjob-39405a010ca796545"
    "mgn.amazonaws.com-source-server"              = "s-306129d7833208c43"
    "pbs:billing:environment"                      = "Dev"
    "pbs:billing:owner"                            = "Murali-Rajendran"
    "pbs:billing:product"                          = "SnoarQube"
  }
}

import {
  to = aws_instance.s_sbap01_dat1_x
  id = "i-04bc18689d5d8a9c5"
}