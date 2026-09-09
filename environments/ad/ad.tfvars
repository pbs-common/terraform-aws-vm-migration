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

# 20 AD port entries per CIDR, 60 inbound rules per SG => 3 CIDRs max per SG.
# The primary SG also carries the VPC CIDR, so it holds 2 consuming CIDRs.

# soc (10.168.0.0/16) + cchq (10.68.50.0/24)
consuming_vpc_cidr_blocks = ["10.168.0.0/16", "10.68.50.0/24"]

# az - not yet routed via the TGW
overflow_cidr_blocks = ["10.190.4.0/24", "10.191.4.0/24", "10.164.0.0/16"]

overflow2_cidr_blocks = ["10.64.0.0/16"]

key_name = null

# MGN Configuration
environment_name            = "ad"
mgn_staging_az              = "us-east-1a"
mgn_staging_subnet_cidr     = "172.31.100.0/24"
mgn_create_internet_gateway = false
mgn_internet_gateway_id     = null
mgn_source_vpc_cidr_blocks  = ["10.0.0.0/8"]
mgn_target_vpc_cidr_blocks  = ["172.31.0.0/16"]
mgn_cross_account_role_arns = []
enable_mgn_ebs_encryption   = true
mgn_kms_key_arn             = null

# Common tags for MGN resources
common_tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "ad"
  "pbs:billing:product"     = "active-directory"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}
