# MGN Replication Baseline Infrastructure
# This module provisions the shared replication substrate for AWS Application Migration Service (MGN)

locals {
  mgn_prefix = "${var.environment_name}-mgn"
  
  common_tags = merge(
    var.tags,
    {
      Managed_By  = "Terraform"
      Module      = "mgn-replication-baseline"
      Environment = var.environment_name
    }
  )
}

# ============================================================================
# Staging Subnet with Internet Gateway for Replication Agent Outbound Access
# ============================================================================

resource "aws_subnet" "mgn_staging" {
  vpc_id                          = var.vpc_id
  cidr_block                      = var.staging_subnet_cidr
  availability_zone               = var.staging_az
  map_public_ip_on_launch         = false
  assign_ipv6_address_on_creation = false

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-staging-subnet" }
  )
}

# Internet Gateway for replication agent outbound access
resource "aws_internet_gateway" "mgn" {
  vpc_id = var.vpc_id

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-igw" }
  )
}

# Route table for staging subnet with IGW route
resource "aws_route_table" "mgn_staging" {
  vpc_id = var.vpc_id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.mgn.id
  }

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-staging-rt" }
  )
}

resource "aws_route_table_association" "mgn_staging" {
  subnet_id      = aws_subnet.mgn_staging.id
  route_table_id = aws_route_table.mgn_staging.id
}

# Optional: Direct Connect route for replication traffic (if configured)
resource "aws_route" "mgn_direct_connect" {
  count = var.enable_direct_connect_path ? 1 : 0

  route_table_id = aws_route_table.mgn_staging.id
  destination_cidr_block = "10.0.0.0/8" # Adjust as needed for on-prem CIDR
  # Note: Direct Connect is managed outside Terraform via Virtual Interface
  # This route assumes DX VIF is already attached to the VGW and propagated
}

# ============================================================================
# Network ACL for Replication Traffic
# ============================================================================

resource "aws_network_acl" "mgn_staging" {
  vpc_id     = var.vpc_id
  subnet_ids = [aws_subnet.mgn_staging.id]

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-staging-nacl" }
  )

  # Inbound rules
  # Allow replication from source networks
  dynamic "ingress" {
    for_each = var.source_vpc_cidr_blocks
    content {
      protocol   = "tcp"
      rule_no    = 100 + ingress.key
      action     = "allow"
      cidr_block = ingress.value
      from_port  = 1024
      to_port    = 65535
    }
  }

  # Allow ephemeral ports for responses
  ingress {
    protocol   = "tcp"
    rule_no    = 32000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  ingress {
    protocol   = "udp"
    rule_no    = 32001
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound rules
  # Allow replication traffic to source networks
  dynamic "egress" {
    for_each = var.source_vpc_cidr_blocks
    content {
      protocol   = "tcp"
      rule_no    = 100 + egress.key
      action     = "allow"
      cidr_block = egress.value
      from_port  = 443  # MGN replication uses HTTPS
      to_port    = 443
    }
  }

  # Allow outbound HTTPS for agent communication and API calls
  egress {
    protocol   = "tcp"
    rule_no    = 32000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow outbound DNS
  egress {
    protocol   = "udp"
    rule_no    = 32001
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 53
    to_port    = 53
  }
}

# ============================================================================
# Security Groups for Replication
# ============================================================================

# Security group for staging subnet
resource "aws_security_group" "mgn_staging" {
  name        = "${local.mgn_prefix}-staging-sg"
  description = "Security group for MGN staging subnet - replication traffic"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-staging-sg" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Allow replication traffic from source networks
resource "aws_vpc_security_group_ingress_rule" "mgn_from_source" {
  for_each = toset(var.source_vpc_cidr_blocks)

  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN replication from ${each.value}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value

  tags = { Name = "mgn-replication-from-${replace(each.value, "/", "-")}" }
}

# Allow communication within staging subnet
resource "aws_vpc_security_group_ingress_rule" "mgn_staging_internal" {
  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN staging subnet internal communication"
  from_port         = 0
  to_port           = 65535
  ip_protocol       = "tcp"
  referenced_security_group_id = aws_security_group.mgn_staging.id

  tags = { Name = "mgn-staging-internal" }
}

# Allow outbound HTTPS for replication and agent communication
resource "aws_vpc_security_group_egress_rule" "mgn_replication_https" {
  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN outbound replication and API communication"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "mgn-replication-https-out" }
}

# Allow outbound DNS
resource "aws_vpc_security_group_egress_rule" "mgn_dns" {
  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN outbound DNS"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "mgn-dns-out" }
}

# Security group for replication agents on source servers
resource "aws_security_group" "mgn_agent" {
  name        = "${local.mgn_prefix}-agent-sg"
  description = "Security group for servers with MGN replication agent installed"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    { Name = "${local.mgn_prefix}-agent-sg" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Agent allows outbound to MGN endpoint (AWS)
resource "aws_vpc_security_group_egress_rule" "mgn_agent_to_endpoint" {
  security_group_id = aws_security_group.mgn_agent.id
  description       = "MGN agent to AWS MGN endpoint"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "mgn-agent-to-endpoint" }
}

# Agent allows outbound DNS
resource "aws_vpc_security_group_egress_rule" "mgn_agent_dns" {
  security_group_id = aws_security_group.mgn_agent.id
  description       = "MGN agent DNS resolution"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"

  tags = { Name = "mgn-agent-dns-out" }
}

# ============================================================================
# IAM Roles and Policies
# ============================================================================

# MGN Replication Service Role (for AWS to perform replication)
resource "aws_iam_role" "mgn_service_role" {
  name               = "${local.mgn_prefix}-service-role"
  assume_role_policy = data.aws_iam_policy_document.mgn_service_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "mgn_service_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["mgn.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# MGN Service policy with least privilege
resource "aws_iam_role_policy" "mgn_service_policy" {
  name   = "${local.mgn_prefix}-service-policy"
  role   = aws_iam_role.mgn_service_role.id
  policy = data.aws_iam_policy_document.mgn_service_policy.json
}

data "aws_iam_policy_document" "mgn_service_policy" {
  statement {
    sid    = "EC2Permissions"
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateVolume",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:DescribeInstanceAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "EBSEncryption"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = var.kms_key_arn != null ? [var.kms_key_arn] : ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "EBSDefaultEncryption"
    effect = "Allow"
    actions = [
      "ec2:EnableEbsEncryption",
      "ec2:GetEbsEncryptionByDefault",
      "ec2:ModifyEbsDefaultEncryption",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "TagResources"
    effect = "Allow"
    actions = [
      "ec2:CreateTags",
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:*:volume/*",
      "arn:aws:ec2:${var.aws_region}:*:snapshot/*",
    ]
  }

  statement {
    sid    = "DenyUnsecureTransport"
    effect = "Deny"
    actions = [
      "ec2:*",
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# MGN Agent Execution Role (for EC2 instances running the agent)
resource "aws_iam_role" "mgn_agent_role" {
  name               = "${local.mgn_prefix}-agent-role"
  assume_role_policy = data.aws_iam_policy_document.mgn_agent_assume.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "mgn_agent_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# Agent policy - minimal permissions
resource "aws_iam_role_policy" "mgn_agent_policy" {
  name   = "${local.mgn_prefix}-agent-policy"
  role   = aws_iam_role.mgn_agent_role.id
  policy = data.aws_iam_policy_document.mgn_agent_policy.json
}

data "aws_iam_policy_document" "mgn_agent_policy" {
  statement {
    sid    = "MgnAgentCommunication"
    effect = "Allow"
    actions = [
      "mgn:ChangeServerLifeCycleState",
      "mgn:GetReplicationConfiguration",
      "mgn:UpdateReplicationConfiguration",
      "mgn:PutSourceServerAction",
      "mgn:UpdateSourceServer",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/mgn/*"]
  }

  statement {
    sid    = "SSMAccess"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:GetMessages",
    ]
    resources = ["*"]
  }
}

# Instance profile for agent role
resource "aws_iam_instance_profile" "mgn_agent" {
  name = "${local.mgn_prefix}-agent-profile"
  role = aws_iam_role.mgn_agent_role.name
}

# ============================================================================
# Cross-Account Connector Setup
# ============================================================================

# Cross-account replication role (for other AWS accounts to assume)
resource "aws_iam_role" "mgn_cross_account_role" {
  count = length(var.cross_account_mgn_role_arns) > 0 ? 1 : 0
  
  name               = "${local.mgn_prefix}-cross-account-role"
  assume_role_policy = data.aws_iam_policy_document.mgn_cross_account_assume[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "mgn_cross_account_assume" {
  count = length(var.cross_account_mgn_role_arns) > 0 ? 1 : 0
  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.cross_account_mgn_role_arns
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["mgn-${var.environment_name}-${data.aws_caller_identity.current.account_id}"]
    }
  }
}

resource "aws_iam_role_policy" "mgn_cross_account_policy" {
  count = length(var.cross_account_mgn_role_arns) > 0 ? 1 : 0
  
  name   = "${local.mgn_prefix}-cross-account-policy"
  role   = aws_iam_role.mgn_cross_account_role[0].id
  policy = data.aws_iam_policy_document.mgn_cross_account_policy[0].json
}

data "aws_iam_policy_document" "mgn_cross_account_policy" {
  count = length(var.cross_account_mgn_role_arns) > 0 ? 1 : 0
  
  statement {
    sid    = "AllowCrossAccountReplication"
    effect = "Allow"
    actions = [
      "mgn:*",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
      "ec2:CreateVolume",
      "ec2:CreateSnapshot",
      "ec2:AttachVolume",
      "ec2:DetachVolume",
    ]
    resources = ["*"]
  }
}

# ============================================================================
# MGN Replication Configuration Template
# ============================================================================

resource "aws_ssm_parameter" "mgn_replication_settings" {
  name        = "/${var.environment_name}/mgn/replication-settings"
  description = "Default MGN replication settings template for ${var.environment_name}"
  type        = "String"
  value = jsonencode({
    replicationServers = {
      stagingAreaSubnetId = aws_subnet.mgn_staging.id
      stagingAreaTags     = merge(local.common_tags, { Purpose = "MGN-Staging" })
      replicatedDisks = {
        ebsOptimized        = true
        ebsEncryption       = var.enable_ebs_encryption ? "DEFAULT" : "NONE"
        kmsKeyArn          = var.kms_key_arn
      }
    }
    dataPlaneRouting   = "PRIVATE_IP"
    defaultLargeStagingDiskType = "gp3"
    ebsEncryption     = var.enable_ebs_encryption ? "DEFAULT" : "NONE"
    replicationServerInstanceType = "t3.small"
    useDedicatedReplicationServer = true
    volumeEncryptionKeyArn = var.kms_key_arn
    associateDefaultSecurityGroup = false
    bandwidthThrottling = 100  # Mbps
    createPublicIP      = false
    dataPlaneRouting   = "PRIVATE_IP"
    defaultLargeStagingDiskType = "gp3"
    ebsOptimized       = true
    replicationServersSecurityGroupsIDs = [aws_security_group.mgn_staging.id]
    stagingAreaSubnetId = aws_subnet.mgn_staging.id
    stagingAreaTags    = merge(local.common_tags, { Purpose = "MGN-Staging" })
    useDedicatedReplicationServer = true
  })

  tags = local.common_tags
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# Monitoring and Logging
# ============================================================================

# CloudWatch Log Group for MGN
resource "aws_cloudwatch_log_group" "mgn_replication" {
  name              = "/aws/mgn/${var.environment_name}/replication"
  retention_in_days = 30

  tags = local.common_tags
}

# CloudWatch Log Group for agents
resource "aws_cloudwatch_log_group" "mgn_agents" {
  name              = "/aws/mgn/${var.environment_name}/agents"
  retention_in_days = 30

  tags = local.common_tags
}
