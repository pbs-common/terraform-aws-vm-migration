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
resource "aws_instance" "s_ghsd01_dat1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "m5.xlarge"
}

import {
  to = aws_instance.s_ghsd01_dat1_w
  id = "i-062c6c56e0ea43a52"
}

resource "aws_instance" "s_sits01_dat1_x" {
  ami           = "ami-0cd015083896391d5"
  instance_type = "m5.xlarge"
}

import {
  to = aws_instance.s_sits01_dat1_x
  id = "i-0f15f3836d730abb6"
}

resource "aws_instance" "i_ng_ws_sm_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r5.large"
}

import {
  to = aws_instance.i_ng_ws_sm_t1_w
  id = "i-03cd76dd517b2efb6"
}

resource "aws_instance" "i_ng_ws_bb_t1_w" {
  ami           = "ami-0d16ebbf0d8306d63"
  instance_type = "r5.xlarge"
}

import {
  to = aws_instance.i_ng_ws_bb_t1_w
  id = "i-037e76172f90efc2d"
}

resource "aws_instance" "i_ng_ws_zc_t1_l" {
  ami           = "ami-0b84981f84c45e189"
  instance_type = "m5.xlarge"
}

import {
  to = aws_instance.i_ng_ws_zc_t1_l
  id = "i-03d447ddfcf97efe7"
}