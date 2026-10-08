# EC2 Workload Module

This module provisions a single EC2 instance, either Windows or Linux, along with its own security group, IAM role for SSM Session Manager access, and EBS volumes. It selects a private subnet automatically from a Name-tag prefix and availability zone, and resolves the latest AMI for the chosen OS family when `ami_id` is left null.

## Usage

```hcl
module "dc1" {
  source = "./modules/ec2-workload"

  name                       = "dc1"
  os_family                  = "windows"
  private_subnet_name_prefix = "pbs-sharedtools-useast1-subnet-private"
  availability_zone          = "us-east-1a"

  ingress_rules = [
    {
      description = "LDAP from on-prem"
      from_port   = 389
      to_port     = 389
      protocol    = "tcp"
      cidr_blocks = ["10.168.0.0/16"]
    },
  ]

  tags = {
    Environment = "ad"
  }
}
```

## Ingress and egress rules

Each rule in `ingress_rules`/`egress_rules` sets `cidr_blocks`, `prefix_list_ids`, or both. A rule that references a prefix list counts against the security group's AWS rule quota by that prefix list's `max_entries`, not as a single rule, so plan for that when sizing a security group built from this module.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Value for the mandatory Name tag, also used to derive resource names | `string` | N/A | yes |
| os_family | Operating system family, "windows" or "linux" | `string` | N/A | yes |
| private_subnet_name_prefix | Prefix of the Name tag on candidate subnets | `string` | N/A | yes |
| availability_zone | Availability zone to place the instance in | `string` | N/A | yes |
| ami_id | AMI ID to launch, latest AMI for os_family resolved automatically if null | `string` | `null` | no |
| instance_type | EC2 instance type | `string` | `"t3.large"` | no |
| associate_public_ip_address | Whether to associate a public IP address with the instance | `bool` | `false` | no |
| key_name | EC2 key pair name, RDP fallback on Windows or SSH access on Linux | `string` | `null` | no |
| create_security_group | Whether to create a dedicated security group for the instance | `bool` | `true` | no |
| security_group_ids | Additional existing security group IDs to attach, alongside the one this module creates | `list(string)` | `[]` | no |
| ingress_rules | Ingress rules for the security group this module creates | `list(object)` | `[]` | no |
| egress_rules | Egress rules for the security group this module creates | `list(object)` | allow all outbound | no |
| create_iam_instance_profile | Whether to create a per-instance IAM role with SSM access | `bool` | `true` | no |
| iam_instance_profile_name | Existing IAM instance profile to attach instead of creating one | `string` | `null` | no |
| session_log_group_arn | ARN of the CloudWatch Log Group to grant session logging write access to | `string` | `null` | no |
| additional_iam_policy_arns | Additional IAM policy ARNs to attach to the role this module creates | `list(string)` | `[]` | no |
| root_volume_size | Size in GiB of the root EBS volume | `number` | `100` | no |
| root_volume_type | Type of the root EBS volume | `string` | `"gp3"` | no |
| root_volume_encrypted | Whether the root EBS volume is encrypted | `bool` | `true` | no |
| kms_key_id | KMS key ID or ARN for EBS volume encryption, account default used if null | `string` | `null` | no |
| ebs_volumes | Additional EBS volumes to attach | `list(object)` | `[]` | no |
| enable_termination_protection | Whether to enable EC2 termination protection | `bool` | `true` | no |
| monitoring | Whether to enable detailed one minute CloudWatch monitoring | `bool` | `true` | no |
| patch_group | Value for the Patch Group tag used by SSM Patch Manager | `string` | `null` | no |
| user_data | Optional user data script to run on first boot | `string` | `null` | no |
| tags | Tags to apply to every resource this module creates | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | ID of the EC2 instance |
| private_ip | Private IP address of the instance |
| public_ip | Public IP address of the instance, if associated |
| ami_id | AMI ID the instance was launched from |
| instance_type | Instance type the instance is running as |
| security_group_id | ID of the security group this module created, if any |
| iam_role_arn | ARN of the IAM role this module created, if any |
| iam_instance_profile_name | Name of the IAM instance profile attached to the instance |
| vpc_id | ID of the VPC the selected subnet belongs to |
| subnet_id | ID of the private subnet the instance was placed in |
