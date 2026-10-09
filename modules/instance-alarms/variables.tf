variable "environment" {
  description = "Environment name prefix for alarm names, e.g. \"ad\" or \"staging\"."
  type        = string
}

variable "instance_name" {
  description = "Short name for this instance, used in alarm names, e.g. \"dc1\"."
  type        = string
}

variable "instance_id" {
  description = "The instance's real ID - reference its aws_instance/module resource directly, don't hardcode."
  type        = string
}

variable "image_id" {
  description = "The instance's AMI ID. Required as a CWAgent metric dimension."
  type        = string
}

variable "instance_type" {
  description = "The instance's type. Required as a CWAgent metric dimension."
  type        = string
}

variable "os_family" {
  description = "\"windows\" or \"linux\". Picks the CWAgent metric name, dimension shape, and comparison direction - Windows measures free space, Linux measures used space."
  type        = string

  validation {
    condition     = contains(["windows", "linux"], var.os_family)
    error_message = "os_family must be \"windows\" or \"linux\"."
  }
}

variable "disks" {
  description = "Disks to alarm on, each gets the standard 8/4/0 free-percent alarm set. Windows: set drive_letter (e.g. \"C:\"). Linux: set path/device/fstype. label suffixes the alarm name (e.g. \"home\" for /home) - leave empty for the primary disk."
  type = list(object({
    label        = optional(string, "")
    drive_letter = optional(string)
    path         = optional(string)
    device       = optional(string)
    fstype       = optional(string)
  }))

  validation {
    # Disks are keyed by label internally - a duplicate silently drops one disk's alarms.
    condition     = length(var.disks) == length(distinct([for d in var.disks : d.label]))
    error_message = "Each entry in disks must have a unique label (leave label unset for only one disk)."
  }
}

variable "routine_topic_arn" {
  description = "SNS topic ARN for routine-severity notifications (disk at 8% free)."
  type        = string
}

variable "critical_topic_arn" {
  description = "SNS topic ARN for critical-severity notifications (disk at 4%/0% free, unreachable). Defaults to routine_topic_arn for environments with no separate critical channel."
  type        = string
  default     = null
}

variable "actions_enabled" {
  description = "Whether these alarms notify on state change. Set false for an initial rollout so alarms settle into real state without firing."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to each alarm, merged with an automatic Name tag."
  type        = map(string)
  default     = {}
}
