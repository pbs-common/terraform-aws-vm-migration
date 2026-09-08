# MGN Replication Baseline for AD Environment
# This configuration provisions the shared replication substrate for AWS Application Migration Service

# Get current VPC information from existing AD infrastructure
data "aws_subnets" "ad_private" {
  filter {
    name   = "tag:Name"
    values = ["${var.private_subnet_name_prefix}-*"]
  }
}

data "aws_subnet" "ad_reference" {
  id = data.aws_subnets.ad_private.ids[0]
}

# Deploy MGN replication baseline
module "mgn_replication_baseline" {
  source = "../../modules/mgn-replication-baseline"

  aws_region                  = var.aws_region
  environment_name            = var.environment_name
  vpc_id                      = data.aws_subnet.ad_reference.vpc_id
  staging_subnet_cidr         = var.mgn_staging_subnet_cidr
  staging_az                  = var.mgn_staging_az
  source_vpc_cidr_blocks      = var.mgn_source_vpc_cidr_blocks
  target_vpc_cidr_blocks      = var.mgn_target_vpc_cidr_blocks
  cross_account_mgn_role_arns = var.mgn_cross_account_role_arns
  enable_direct_connect_path  = var.enable_mgn_direct_connect_path
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
