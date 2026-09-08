aws_region = "us-east-1"

# Golden AMI: AD-DS/DNS installed, not promoted, sysprepped. Built manually.
golden_ami_id = "ami-038905f9eb15c1313"

private_subnet_name_prefix = "pbs-sharedtools-useast1-subnet-private"
dc1_availability_zone      = "us-east-1a"
dc2_availability_zone      = "us-east-1b"

instance_type    = "t3.large"
root_volume_size = 100

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "ad"
  "pbs:billing:product"     = "active-directory"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}

# soc (10.168.0.0/16) + cchq (10.68.50.0/24)
consuming_vpc_cidr_blocks = ["10.168.0.0/16", "10.68.50.0/24"]

# az - not yet routed via the TGW
overflow_cidr_blocks = ["10.190.4.0/24", "10.191.4.0/24"]

key_name = null

environment_name               = "ad"
mgn_staging_az                 = "us-east-1a"
mgn_staging_subnet_cidr        = "10.0.100.0/24"

mgn_source_vpc_cidr_blocks     = ["10.0.0.0/8"]      # Your on-prem network
mgn_target_vpc_cidr_blocks     = ["172.31.0.0/16"]     # Target VPC CIDR

# Cross-account replication (leave empty for now, add later if needed)
mgn_cross_account_role_arns    = []

# Encryption
enable_mgn_ebs_encryption      = true
mgn_kms_key_arn               = null  # Uses AWS managed key

# Tags (merge with your existing tags)
common_tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "ad"
  "pbs:billing:product"     = "active-directory"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}