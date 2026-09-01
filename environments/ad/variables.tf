variable "aws_region" {
  description = "AWS region for the AD environment."
  type        = string
}

variable "private_subnet_name_prefix" {
  description = "Prefix of the Name tag on candidate private subnets for DC1/DC2 (e.g. \"pbs-sharedtools-useast1-subnet-private\"). Combined with each DC's availability zone to resolve a subnet via data source; the VPC ID is derived from it, never hardcoded."
  type        = string
}

variable "dc1_availability_zone" {
  description = "Availability zone for DC1. The module selects a private subnet in this AZ automatically."
  type        = string
}

variable "dc2_availability_zone" {
  description = "Availability zone for DC2. Should differ from dc1_availability_zone for availability."
  type        = string
}

variable "golden_ami_id" {
  description = "AMI ID of the golden image for DC1/DC2 (Windows Server + AD-Domain-Services/DNS features installed, sysprepped, not promoted). Built manually via console/SSM, not by Terraform. Required so DCs don't float onto whatever \"latest\" Windows AMI happens to resolve at apply time."
  type        = string

  validation {
    condition     = length(trimspace(var.golden_ami_id)) > 0
    error_message = "golden_ami_id must not be empty - build the golden AMI first and set its real ami-xxxxxxxx id here."
  }
}

variable "tags" {
  description = "Tags applied to DC1/DC2, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}

variable "instance_type" {
  description = "Instance type for DC1/DC2."
  type        = string
  default     = "t3.large"
}

variable "root_volume_size" {
  description = "Root volume size (GiB) for DC1/DC2."
  type        = number
  default     = 100
}

variable "consuming_vpc_cidr_blocks" {
  description = "CIDR blocks of the workload VPCs that need directory/DNS access to the DCs (AD ports below). Populate as consuming VPCs are onboarded."
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Optional EC2 key pair name, kept as an RDP fallback alongside SSM Session Manager access."
  type        = string
  default     = null
}
