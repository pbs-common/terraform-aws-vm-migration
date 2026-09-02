locals {
  ami_id = coalesce(var.ami_id, try(data.aws_ssm_parameter.windows_2022[0].value, null))

  tags = merge(
    var.tags,
    var.patch_group != null ? { "Patch Group" = var.patch_group } : {},
    { Name = var.name },
  )

  iam_instance_profile_name = var.create_iam_instance_profile ? aws_iam_instance_profile.this[0].name : var.iam_instance_profile_name

  security_group_ids = concat(
    var.create_security_group ? [aws_security_group.this[0].id] : [],
    var.security_group_ids,
  )

  # Private subnets only.
  private_subnet_ids = sort([
    for s in data.aws_subnet.candidates : s.id if !s.map_public_ip_on_launch
  ])
  subnet_id = element(local.private_subnet_ids, 0)
  vpc_id    = data.aws_subnet.candidates[local.subnet_id].vpc_id

  # One entry per (rule, CIDR) pair. Keyed by content, not list position, so
  # adding/removing a rule or CIDR doesn't reshuffle unrelated existing keys.
  ingress_rules_flat = { for r in flatten([
    for rule in var.ingress_rules : [
      for cidr in rule.cidr_blocks : merge(rule, { key = "${rule.protocol}-${rule.from_port}-${rule.to_port}-${cidr}", cidr_block = cidr })
    ]
  ]) : r.key => r }

  egress_rules_flat = { for r in flatten([
    for rule in var.egress_rules : [
      for cidr in rule.cidr_blocks : merge(rule, { key = "${rule.protocol}-${rule.from_port}-${rule.to_port}-${cidr}", cidr_block = cidr })
    ]
  ]) : r.key => r }
}

# Security group

resource "aws_security_group" "this" {
  count = var.create_security_group ? 1 : 0

  name        = "${var.name}-sg"
  description = "Security group for ${var.name}"
  vpc_id      = local.vpc_id

  tags = merge(local.tags, { Name = "${var.name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.create_security_group ? local.ingress_rules_flat : {}

  security_group_id = aws_security_group.this[0].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_block

  tags = merge(local.tags, { Name = "${var.name}-sg-ingress-${replace(each.key, "/", "_")}" })
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.create_security_group ? local.egress_rules_flat : {}

  security_group_id = aws_security_group.this[0].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  cidr_ipv4         = each.value.cidr_block

  tags = merge(local.tags, { Name = "${var.name}-sg-egress-${replace(each.key, "/", "_")}" })
}

# IAM role / instance profile (SSM)

data "aws_iam_policy_document" "assume_role" {
  count = var.create_iam_instance_profile ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_instance_profile ? 1 : 0

  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  count = var.create_iam_instance_profile ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = var.create_iam_instance_profile ? toset(var.additional_iam_policy_arns) : toset([])

  role       = aws_iam_role.this[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_iam_instance_profile ? 1 : 0

  name = "${var.name}-instance-profile"
  role = aws_iam_role.this[0].name
  tags = local.tags
}

# Instance

resource "aws_instance" "this" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = local.subnet_id
  vpc_security_group_ids = local.security_group_ids
  iam_instance_profile   = local.iam_instance_profile_name
  key_name               = var.key_name

  associate_public_ip_address = var.associate_public_ip_address
  disable_api_termination     = var.enable_termination_protection
  monitoring                  = var.monitoring
  user_data                   = var.user_data
  get_password_data           = var.key_name != null

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = var.root_volume_type
    encrypted   = var.root_volume_encrypted
    kms_key_id  = var.kms_key_id
    tags        = local.tags
  }

  dynamic "ebs_block_device" {
    for_each = var.ebs_volumes
    content {
      device_name = ebs_block_device.value.device_name
      volume_size = ebs_block_device.value.size
      volume_type = ebs_block_device.value.type
      encrypted   = ebs_block_device.value.encrypted
      kms_key_id  = var.kms_key_id
      tags        = local.tags
    }
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [ami]
  }
}
