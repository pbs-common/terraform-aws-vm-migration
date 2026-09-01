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

consuming_vpc_cidr_blocks = []

key_name = null
