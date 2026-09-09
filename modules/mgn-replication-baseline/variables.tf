variable "aws_region" {
  description = "AWS region for MGN resources"
  type        = string
}

variable "environment_name" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where staging subnet will be created"
  type        = string
}

variable "staging_subnet_cidr" {
  description = "CIDR block for MGN staging area subnet"
  type        = string
  default     = "10.0.100.0/24"
}

variable "staging_az" {
  description = "Availability zone for staging subnet"
  type        = string
}

variable "create_internet_gateway" {
  description = "Whether to create a new Internet Gateway (set to false if VPC already has one)"
  type        = bool
  default     = true
}

variable "internet_gateway_id" {
  description = "Existing Internet Gateway ID to use (if create_internet_gateway is false)"
  type        = string
  default     = null
}

variable "source_vpc_cidr_blocks" {
  description = "CIDR blocks of source VPCs/on-prem networks for replication traffic"
  type        = list(string)
}

variable "target_vpc_cidr_blocks" {
  description = "CIDR blocks of target VPCs for workload placement after replication"
  type        = list(string)
}

variable "cross_account_mgn_role_arns" {
  description = "List of cross-account MGN role ARNs for outbound connectors (e.g., [\"arn:aws:iam::123456789012:role/mgn-replication-role\"])"
  type        = list(string)
  default     = []
}

variable "enable_ebs_encryption" {
  description = "Enable EBS encryption at rest for replicated volumes"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "KMS key ARN for EBS encryption (uses AWS managed key if not provided)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
