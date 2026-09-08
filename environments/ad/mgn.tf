# MGN Replication Baseline for AD Environment
# This configuration provisions the shared replication substrate for AWS Application Migration Service

# Use default VPC for MGN staging infrastructure
data "aws_vpc" "default" {
  default = true
}

# Get the existing Internet Gateway from the default VPC
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Deploy MGN replication baseline
module "mgn_replication_baseline" {
  source = "../../modules/mgn-replication-baseline"

  aws_region                  = var.aws_region
  environment_name            = var.environment_name
  vpc_id                      = data.aws_vpc.default.id
  staging_subnet_cidr         = var.mgn_staging_subnet_cidr
  staging_az                  = var.mgn_staging_az
  source_vpc_cidr_blocks      = var.mgn_source_vpc_cidr_blocks
  target_vpc_cidr_blocks      = var.mgn_target_vpc_cidr_blocks
  cross_account_mgn_role_arns = var.mgn_cross_account_role_arns
  create_internet_gateway     = false
  internet_gateway_id         = data.aws_internet_gateway.default.id
  enable_ebs_encryption       = var.enable_mgn_ebs_encryption
  kms_key_arn                 = var.mgn_kms_key_arn

  tags = local.common_tags
}

# ============================================================================
# Local Values
# ============================================================================

locals {
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment_name
      Project     = "AWS-VM-Migration"
      ManagedBy   = "Terraform"
    }
  )
}
