variable "name" {
  description = "Value for the mandatory Name tag. Also used to derive resource names (security group, IAM role, etc.)."
  type        = string

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "os_family" {
  description = "Operating system family (\"windows\" or \"linux\"). Drives AMI auto-resolution and Windows-only RDP password retrieval."
  type        = string

  validation {
    condition     = contains(["windows", "linux"], var.os_family)
    error_message = "os_family must be \"windows\" or \"linux\"."
  }
}

variable "ami_id" {
  description = "AMI ID to launch. If null, the latest AMI for os_family is resolved via the public SSM parameter (Windows Server 2022 Full Base, or Amazon Linux 2023)."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.large"
}

variable "private_subnet_name_prefix" {
  description = "Prefix of the Name tag on candidate subnets (e.g. \"pbs-sharedtools-useast1-subnet-private\" matches \"...-private-0\", \"...-private-1\", etc). Combined with availability_zone to select exactly one subnet via data source. The VPC ID is derived from that subnet - never looked up or hardcoded separately."
  type        = string
}

variable "availability_zone" {
  description = "Availability zone to place the instance in. The module selects a private subnet (map_public_ip_on_launch = false) matching private_subnet_name_prefix in this AZ via data source; it fails if none exists."
  type        = string
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = false
}

variable "key_name" {
  description = "EC2 key pair name. For Windows, used as an RDP password-decryption fallback alongside SSM Session Manager. For Linux, used for SSH key-pair access."
  type        = string
  default     = null
}

# Security group

variable "create_security_group" {
  description = "Whether to create a dedicated security group for the instance."
  type        = bool
  default     = true
}

variable "security_group_ids" {
  description = "Additional existing security group IDs to attach to the instance, alongside the one created by this module (if any)."
  type        = list(string)
  default     = []
}

variable "ingress_rules" {
  description = "Ingress rules for the security group created by this module. Each rule sets cidr_blocks and/or prefix_list_ids. A prefix-list rule counts against the account's configured per-security-group rule quota (AWS default 60, adjustable) as that list's max_entries, not as 1."
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    prefix_list_ids = optional(list(string), [])
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.ingress_rules : length(r.cidr_blocks) > 0 || length(r.prefix_list_ids) > 0])
    error_message = "Each ingress rule must set at least one of cidr_blocks or prefix_list_ids."
  }
}

variable "egress_rules" {
  description = "Egress rules for the security group created by this module. Defaults to allow-all. Same cidr_blocks/prefix_list_ids shape as ingress_rules."
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string
    cidr_blocks     = optional(list(string), [])
    prefix_list_ids = optional(list(string), [])
  }))
  default = [
    {
      description = "Allow all outbound traffic"
      from_port   = -1
      to_port     = -1
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  validation {
    condition     = alltrue([for r in var.egress_rules : length(r.cidr_blocks) > 0 || length(r.prefix_list_ids) > 0])
    error_message = "Each egress rule must set at least one of cidr_blocks or prefix_list_ids."
  }
}

# IAM / SSM

variable "create_iam_instance_profile" {
  description = "Whether to create a per-instance IAM role with SSM access, seeded with the same permissions as the org's shared pbs-ssm-role. Set false to attach an existing instance profile instead."
  type        = bool
  default     = true
}

variable "iam_instance_profile_name" {
  description = "Existing IAM instance profile to attach instead of creating one. Required if create_iam_instance_profile is false."
  type        = string
  default     = null
}

variable "session_log_group_arn" {
  description = "ARN of the CloudWatch Log Group to grant session-logging write access to. Leave null to skip."
  type        = string
  default     = null
}

variable "additional_iam_policy_arns" {
  description = "Additional IAM policy ARNs to attach to the role created by this module. Ignored if create_iam_instance_profile is false."
  type        = list(string)
  default     = []
}

# Storage

variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume."
  type        = number
  default     = 100
}

variable "root_volume_type" {
  description = "Type of the root EBS volume."
  type        = string
  default     = "gp3"
}

variable "root_volume_encrypted" {
  description = "Whether the root EBS volume is encrypted."
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID/ARN to use for EBS volume encryption. Defaults to the account default EBS key when null."
  type        = string
  default     = null
}

variable "ebs_volumes" {
  description = "Additional EBS volumes to attach (e.g. a dedicated volume for the AD database/logs/SYSVOL)."
  type = list(object({
    device_name = string
    size        = number
    type        = optional(string, "gp3")
    encrypted   = optional(bool, true)
  }))
  default = []
}

# Misc

variable "enable_termination_protection" {
  description = "Whether to enable EC2 termination protection (disable_api_termination)."
  type        = bool
  default     = true
}

variable "monitoring" {
  description = "Whether to enable detailed (1-minute) CloudWatch monitoring."
  type        = bool
  default     = true
}

variable "patch_group" {
  description = "Value for the 'Patch Group' tag, used by SSM Patch Manager to target this instance with a patch baseline. Left untagged when null."
  type        = string
  default     = null
}

variable "user_data" {
  description = "Optional user data script to run on first boot."
  type        = string
  default     = null
}

# Tagging

variable "tags" {
  description = "Tags to apply to every resource created by this module, merged with an automatic Name tag from var.name."
  type        = map(string)
  default     = {}
}
