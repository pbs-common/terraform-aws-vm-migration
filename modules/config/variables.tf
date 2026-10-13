variable "notification_topic_arn" {
  description = "SNS topic ARN for non-compliance alerts when create_notification_topic is false."
  type        = string
  default     = null
}

variable "create_notification_topic" {
  description = "Whether to create a dedicated SNS topic for non-compliance alerts."
  type        = bool
  default     = true

  validation {
    condition     = var.create_notification_topic ? var.alert_email != null : var.notification_topic_arn != null
    error_message = "Provide alert_email when creating a notification topic, or notification_topic_arn when using an existing topic."
  }
}

variable "alert_email" {
  description = "Email address that receives non-compliance alerts (must confirm the SNS subscription). Only used if notification_topic_arn is not provided."
  type        = string
  default     = null
}

variable "lambda_artifact_s3_bucket" {
  description = "S3 bucket for storing Lambda deployment package. If not provided, a bucket will be created."
  type        = string
  default     = null
}

variable "lambda_artifact_s3_prefix" {
  description = "S3 key prefix for the Lambda deployment package (content hash appended automatically)."
  type        = string
  default     = "lambda-artifacts/config"
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
    Each key is a check that every instance must pass; the list holds acceptable
    metric identifiers. Metric names can be plain (e.g., "CPUUtilization") to use
    default namespaces (AWS/EC2 for cpu, CWAgent for memory/disk), or explicitly
    namespaced with "Namespace:MetricName" format (e.g., "AWS/EC2:CPUUtilization").
    Match these to the metric names and namespaces in your CloudWatch agent config.
  EOT
  type        = map(list(string))
  default = {
    cpu    = ["AWS/EC2:CPUUtilization"]
    memory = ["CWAgent:mem_used_percent", "CWAgent:Memory % Committed Bytes In Use"]
    disk   = ["CWAgent:disk_used_percent", "CWAgent:LogicalDisk % Free Space"]
  }
}

variable "require_alarm_actions" {
  description = "Only count alarms that have actions enabled and at least one alarm action."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to every resource created by this module, merged with an automatic Name tag from var.rule_name."
  type        = map(string)
  default     = {}
}