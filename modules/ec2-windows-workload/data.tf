# Latest Windows Server 2022 AMI, used when var.ami_id is not set.
data "aws_ssm_parameter" "windows_2022" {
  count = var.ami_id == null ? 1 : 0

  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# Candidate subnets, matched by Name-tag prefix and AZ.
data "aws_subnets" "candidates" {
  filter {
    name   = "tag:Name"
    values = ["${var.private_subnet_name_prefix}*"]
  }

  filter {
    name   = "availability-zone"
    values = [var.availability_zone]
  }
}

data "aws_subnet" "candidates" {
  for_each = toset(data.aws_subnets.candidates.ids)

  id = each.value
}
