# MGN Configuration Variables

variable "environment_name" {
  description = "Environment name (e.g., prod, staging, dev)"
  type        = string
  default     = "ad"
}

variable "mgn_staging_subnet_cidr" {
  description = "CIDR block for MGN staging area subnet"
  type        = string
  default     = "10.0.100.0/24"
}

variable "mgn_staging_az" {
  description = "Availability zone for MGN staging subnet"
  type        = string
}

variable "mgn_source_vpc_cidr_blocks" {
  description = "CIDR blocks of source VPCs/on-prem networks that will replicate"
  type        = list(string)
  default     = ["10.0.0.0/8"] # Adjust based on your on-prem network
}

variable "mgn_target_vpc_cidr_blocks" {
  description = "CIDR blocks of target VPCs where workloads will be placed after replication"
  type        = list(string)
  default     = []
}

variable "mgn_cross_account_role_arns" {
  description = "List of cross-account MGN role ARNs for outbound replication connectors"
  type        = list(string)
  default     = []
  # Example: ["arn:aws:iam::123456789012:role/mgn-replication-role", "arn:aws:iam::987654321098:role/mgn-replication-role"]
}

variable "enable_mgn_direct_connect_path" {
  description = "Enable Direct Connect route for replication traffic"
  type        = bool
  default     = false
}

variable "mgn_direct_connect_vif_id" {
  description = "Direct Connect Virtual Interface ID (if enable_mgn_direct_connect_path is true)"
  type        = string
  default     = null
}

variable "enable_mgn_ebs_encryption" {
  description = "Enable EBS encryption at rest for replicated volumes"
  type        = bool
  default     = true
}

variable "mgn_kms_key_arn" {
  description = "KMS key ARN for EBS encryption (uses AWS managed key if not provided)"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
