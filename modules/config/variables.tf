variable "alert_email" {
  description = "Email address that receives non-compliance alerts (must confirm the SNS subscription)."
  type        = string
}

variable "create_recorder" {
  description = "Whether to create the AWS Config recorder and delivery channel. Set to false if already configured in your account."
  type        = bool
  default     = true
}

variable "rule_name" {
  description = "Name of the AWS Config rule and related resources."
  type        = string
  default     = "ec2-required-cloudwatch-alarms"
}

variable "evaluation_frequency" {
  description = "How often Config runs the check: One_Hour, Three_Hours, Six_Hours, Twelve_Hours or TwentyFour_Hours."
  type        = string
  default     = "One_Hour"
}

variable "config_bucket_name_prefix" {
  description = "Prefix for the S3 bucket that stores AWS Config snapshots (account ID and region appended automatically)."
  type        = string
  default     = "aws-config-bucket"
}

variable "config_snapshot_frequency" {
  description = "Frequency of Config snapshots: One_Hour, Three_Hours, Six_Hours, Twelve_Hours or TwentyFour_Hours."
  type        = string
  default     = "Six_Hours"
}

variable "required_metrics" {
  description = <<-EOT
    Each key is a check that every instance must pass; the list holds the metric
    names that satisfy it. Match these to the metric names in your CloudWatch
    agent config (defaults cover the agent's standard Linux and Windows names).
  EOT
  type        = map(list(string))
  default = {
    cpu    = ["CPUUtilization"]
    memory = ["mem_used_percent", "Memory % Committed Bytes In Use"]
    disk   = ["disk_used_percent", "LogicalDisk % Free Space"]
  }
}

variable "require_alarm_actions" {
  description = "Only count alarms that have actions enabled and at least one alarm action."
  type        = bool
  default     = true
}
