module "ec2" {
  source = "../../modules/ec2-workload"

  name                       = "demo-instance-1"
  os_family                  = "windows"
  private_subnet_name_prefix = "pbs-devtest-useast1-subnet-private"
  availability_zone          = "us-east-1a"

  ingress_rules = [
    {
      description = "RDP from on-prem"
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["10.168.0.0/16"]
    },
  ]

  tags = {
    "pbs:billing:environment" = "dev"
    "pbs:billing:product"     = "dev"
    "pbs:billing:owner"       = "infra"
    "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
  }
}
