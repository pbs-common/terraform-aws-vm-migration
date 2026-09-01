# Required AD DS ports (Microsoft-documented).
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
    { description = "LDAP GC (TCP)", from_port = 3268, to_port = 3268, protocol = "tcp" },
    { description = "LDAPS GC (TCP)", from_port = 3269, to_port = 3269, protocol = "tcp" },
    { description = "RPC dynamic port range (TCP)", from_port = 49152, to_port = 65535, protocol = "tcp" },
  ]

  # VPC CIDR covers DC1<->DC2 replication; consuming VPCs get the same ports.
  allowed_cidr_blocks = distinct(concat(
    [data.aws_vpc.this.cidr_block],
    var.consuming_vpc_cidr_blocks,
  ))

  ad_ingress_rules = [
    for pair in setproduct(local.ad_ports, local.allowed_cidr_blocks) : {
      description = "${pair[0].description} from ${pair[1]}"
      from_port   = pair[0].from_port
      to_port     = pair[0].to_port
      protocol    = pair[0].protocol
      cidr_blocks = [pair[1]]
    }
  ]
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

module "dc1" {
  source = "../../modules/ec2-windows-workload"

  name                       = "dc1"
  ami_id                     = var.golden_ami_id
  private_subnet_name_prefix = var.private_subnet_name_prefix
  availability_zone          = var.dc1_availability_zone
  instance_type              = var.instance_type
  key_name                   = var.key_name

  root_volume_size = var.root_volume_size

  ingress_rules = local.ad_ingress_rules

  patch_group = "ad"

  tags = var.tags
}

module "dc2" {
  source = "../../modules/ec2-windows-workload"

  name                       = "dc2"
  ami_id                     = var.golden_ami_id
  private_subnet_name_prefix = var.private_subnet_name_prefix
  availability_zone          = var.dc2_availability_zone
  instance_type              = var.instance_type
  key_name                   = var.key_name

  root_volume_size = var.root_volume_size

  ingress_rules = local.ad_ingress_rules

  patch_group = "ad"

  tags = var.tags
}
