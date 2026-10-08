# Required AD DS ports (Microsoft-documented), plus ADWS for directory sync consumers.
locals {
  ad_ports = [
    { description = "DNS (TCP)", from_port = 53, to_port = 53, protocol = "tcp" },
    { description = "DNS (UDP)", from_port = 53, to_port = 53, protocol = "udp" },
    { description = "Kerberos (TCP)", from_port = 88, to_port = 88, protocol = "tcp" },
    { description = "Kerberos (UDP)", from_port = 88, to_port = 88, protocol = "udp" },
    { description = "NTP (UDP)", from_port = 123, to_port = 123, protocol = "udp" },
    { description = "RPC endpoint mapper (TCP)", from_port = 135, to_port = 135, protocol = "tcp" },
    { description = "NetBIOS name service (UDP)", from_port = 137, to_port = 137, protocol = "udp" },
    { description = "NetBIOS datagram service (UDP)", from_port = 138, to_port = 138, protocol = "udp" },
    { description = "NetBIOS session service (TCP)", from_port = 139, to_port = 139, protocol = "tcp" },
    { description = "LDAP (TCP)", from_port = 389, to_port = 389, protocol = "tcp" },
    { description = "LDAP (UDP)", from_port = 389, to_port = 389, protocol = "udp" },
    { description = "SMB / DFSR (TCP)", from_port = 445, to_port = 445, protocol = "tcp" },
    { description = "Kerberos password change (TCP)", from_port = 464, to_port = 464, protocol = "tcp" },
    { description = "Kerberos password change (UDP)", from_port = 464, to_port = 464, protocol = "udp" },
    { description = "LDAPS (TCP)", from_port = 636, to_port = 636, protocol = "tcp" },
    { description = "Global Catalog LDAP/LDAPS (TCP)", from_port = 3268, to_port = 3269, protocol = "tcp" },
    { description = "AD Web Services / ADWS (TCP)", from_port = 9389, to_port = 9389, protocol = "tcp" },
    { description = "RPC dynamic port range (TCP)", from_port = 49152, to_port = 65535, protocol = "tcp" },
    { description = "RDP", from_port = 3389, to_port = 3389, protocol = "tcp" },
    { description = "ICMP", from_port = -1, to_port = -1, protocol = "icmp" }
  ]

  # DC1<->DC2 replication, raw CIDR rather than a named group since it's not reused.
  vpc_self_ingress_rules = [
    for port in local.ad_ports : {
      description     = "${port.description} from ${data.aws_vpc.this.cidr_block}"
      from_port       = port.from_port
      to_port         = port.to_port
      protocol        = port.protocol
      cidr_blocks     = [data.aws_vpc.this.cidr_block]
      prefix_list_ids = []
    }
  ]

  # Flatten var.ad_security_groups' nested groups into name -> {sg_key, cidrs}.
  ad_cidr_groups = merge([
    for sg_key, sg in var.ad_security_groups : {
      for group_name, cidrs in sg.groups : group_name => {
        sg_key = sg_key
        cidrs  = cidrs
      }
    }
  ]...)

  # One entry per (group, port) pair - every group gets the same full port set.
  ad_access_ingress_flat = { for r in flatten([
    for group_name, group in local.ad_cidr_groups : [
      for port in local.ad_ports : {
        key            = "${group.sg_key}-${group_name}-${port.protocol}-${port.from_port}-${port.to_port}"
        sg_key         = group.sg_key
        description    = "${port.description} from ${group_name}"
        from_port      = port.from_port
        to_port        = port.to_port
        protocol       = port.protocol
        prefix_list_id = module.ad_cidr_prefix_lists[group_name].id
      }
    ]
  ]) : r.key => r }
}

# Used only to resolve the VPC CIDR above.
data "aws_subnets" "any_private" {
  filter {
    name   = "tag:Name"
    values = ["${var.private_subnet_name_prefix}*"]
  }
}

data "aws_subnet" "sample" {
  id = element(sort(data.aws_subnets.any_private.ids), 0)
}

data "aws_vpc" "this" {
  id = data.aws_subnet.sample.vpc_id
}

module "ad_cidr_prefix_lists" {
  source   = "../../modules/managed-prefix-list"
  for_each = local.ad_cidr_groups

  name        = "ad-access-${each.key}"
  max_entries = length(each.value.cidrs)
  entries     = [for c in each.value.cidrs : { cidr = c }]

  tags = var.tags
}

resource "aws_security_group" "ad_access" {
  for_each = var.ad_security_groups

  name_prefix = "ad-access-${each.key}-"
  description = "AD port access for the ${each.key} CIDR groups"
  vpc_id      = data.aws_vpc.this.id

  tags = merge(var.tags, { Name = "ad-access-${each.key}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ad_access" {
  for_each = local.ad_access_ingress_flat

  security_group_id = aws_security_group.ad_access[each.value.sg_key].id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.protocol
  prefix_list_id    = each.value.prefix_list_id

  tags = merge(var.tags, { Name = "ad-access-${each.key}" })
}

locals {
  # Sourced from the rules, not the SGs directly, so attachment waits for rules to exist.
  ad_access_sg_ids = distinct([for rule in aws_vpc_security_group_ingress_rule.ad_access : rule.security_group_id])
}

resource "aws_cloudwatch_log_group" "ssm_sessions" {
  name              = "/aws/ssm/session-logs/ad"
  retention_in_days = 90
  tags              = var.tags
}

# Account-level Session Manager preferences. Points sessions at the log group above.
resource "aws_ssm_document" "session_manager_prefs" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold regional settings for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.ssm_sessions.name
      cloudWatchEncryptionEnabled = true
    }
  })

  tags = var.tags
}

module "dc1" {
  source = "../../modules/ec2-workload"

  name                       = "dc1"
  os_family                  = "windows"
  ami_id                     = var.golden_ami_id
  private_subnet_name_prefix = var.private_subnet_name_prefix
  availability_zone          = var.dc1_availability_zone
  instance_type              = var.instance_type
  key_name                   = var.key_name

  root_volume_size      = var.root_volume_size
  session_log_group_arn = aws_cloudwatch_log_group.ssm_sessions.arn

  ingress_rules      = local.vpc_self_ingress_rules
  security_group_ids = local.ad_access_sg_ids

  patch_group = "ad"

  tags = merge(var.tags, {
    daily_backups = "true"
  })
}

module "ssm_session_access" {
  source = "../../modules/ssm-session-access-policy"

  name = "pbs-ssm-session-access-policy"
  tags = {
    "map-migrated" = "mig5T578AWUOW"
  }
}

module "dc2" {
  source = "../../modules/ec2-workload"

  name                       = "dc2"
  os_family                  = "windows"
  ami_id                     = var.golden_ami_id
  private_subnet_name_prefix = var.private_subnet_name_prefix
  availability_zone          = var.dc2_availability_zone
  instance_type              = var.instance_type
  key_name                   = var.key_name

  root_volume_size      = var.root_volume_size
  session_log_group_arn = aws_cloudwatch_log_group.ssm_sessions.arn

  ingress_rules      = local.vpc_self_ingress_rules
  security_group_ids = local.ad_access_sg_ids

  patch_group = "ad"

  tags = merge(var.tags, {
    daily_backups = "true"
  })
}

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

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = "AWSApplicationMigrationLaunchInstanceWithSsmRole"
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# No-op today (ad has no MGN-imported instances), ready automatically if one
# ever lands here. Covers instances adopted via import, which never call
# ec2-workload and so never get its per-instance association.
resource "aws_ssm_association" "cloudwatch_agent" {
  name = "AWSQuickSetupType-InstallAndManageCloudWatchAgent"

  targets {
    key    = "tag-key"
    values = ["AWSApplicationMigrationServiceSourceServerID"]
  }

  parameters = {
    isInstall                     = "true"
    isConfigure                   = "true"
    optionalConfigurationSource   = "default"
    optionalConfigurationLocation = ""
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cloudwatch_agent]
}

locals {
  # ami/instance_type per managed instance, merged into CWAgent alarm dimensions
  # below so they can't go stale after a resize or replacement. ami comes out
  # marked sensitive (ec2-workload's golden_ami_id lookup propagates that), so
  # these alarms' dimensions show as "(sensitive value)" in plan output -
  # harmless, just a plan-readability quirk, not a real secret.
  instance_identity = {
    "i-0c3f94aab892dc2aa" = { ami = module.dc1.ami_id, instance_type = module.dc1.instance_type }
    "i-092b297b4d11cdb21" = { ami = module.dc2.ami_id, instance_type = module.dc2.instance_type }
  }

  cloudwatch_alerts_alarms = [
    for alarm in var.cloudwatch_alerts_alarms : alarm.namespace == "CWAgent" ? merge(alarm, {
      dimensions = merge(alarm.dimensions, {
        ImageId      = local.instance_identity[alarm.dimensions.InstanceId].ami
        InstanceType = local.instance_identity[alarm.dimensions.InstanceId].instance_type
      })
    }) : alarm
  ]
}

module "cloudwatch_alerts" {
  source = "../../modules/cloudwatch-alerts"

  name = "ad"

  notification_channels = var.cloudwatch_alerts_notification_channels

  alarms = local.cloudwatch_alerts_alarms

  tags = var.tags
}
