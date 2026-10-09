locals {
  critical_topic_arn = coalesce(var.critical_topic_arn, var.routine_topic_arn)

  base_dimensions = {
    InstanceId   = var.instance_id
    ImageId      = var.image_id
    InstanceType = var.instance_type
  }

  disks_by_label = { for d in var.disks : d.label => d }

  # Same free-percent policy for every disk: 8% free is routine, 4%/0% free is critical.
  disk_thresholds = {
    "8" = { free_percent = 8, topic_arn = var.routine_topic_arn }
    "4" = { free_percent = 4, topic_arn = local.critical_topic_arn }
    "0" = { free_percent = 0, topic_arn = local.critical_topic_arn }
  }

  disk_alarms = merge([
    for label, disk in local.disks_by_label : {
      for tkey, threshold in local.disk_thresholds : "${label}-${tkey}" => {
        disk      = disk
        threshold = threshold
      }
    }
  ]...)
}

resource "aws_cloudwatch_metric_alarm" "disk_free" {
  for_each = local.disk_alarms

  alarm_name         = join("-", compact([var.environment, var.instance_name, each.value.disk.label, "disk-free-${each.value.threshold.free_percent}"]))
  namespace          = "CWAgent"
  metric_name        = var.os_family == "windows" ? "LogicalDisk % Free Space" : "disk_used_percent"
  statistic          = var.os_family == "windows" ? "Minimum" : "Maximum"
  period             = 300
  evaluation_periods = 1

  # Windows alarms on free space directly; Linux's disk_used_percent is the complement.
  threshold           = var.os_family == "windows" ? each.value.threshold.free_percent : 100 - each.value.threshold.free_percent
  comparison_operator = var.os_family == "windows" ? "LessThanOrEqualToThreshold" : "GreaterThanOrEqualToThreshold"

  dimensions = merge(
    local.base_dimensions,
    var.os_family == "windows"
    ? { instance = each.value.disk.drive_letter, objectname = "LogicalDisk" }
    : { path = each.value.disk.path, device = each.value.disk.device, fstype = each.value.disk.fstype }
  )

  actions_enabled = var.actions_enabled
  alarm_actions   = [each.value.threshold.topic_arn]
  ok_actions      = [each.value.threshold.topic_arn]

  tags = merge(var.tags, { Name = join("-", compact([var.environment, var.instance_name, each.value.disk.label, "disk-free-${each.value.threshold.free_percent}"])) })
}

# Reachability. EC2 status check, no agent needed.
resource "aws_cloudwatch_metric_alarm" "unreachable" {
  alarm_name          = "${var.environment}-${var.instance_name}-unreachable"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = var.instance_id }

  actions_enabled = var.actions_enabled
  alarm_actions   = [local.critical_topic_arn]
  ok_actions      = [local.critical_topic_arn]

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-unreachable" })
}

# Sustained high CPU. Native EC2 metric, no agent needed, same for both OS.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.environment}-${var.instance_name}-cpu-high"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 90
  comparison_operator = "GreaterThanOrEqualToThreshold"
  dimensions          = { InstanceId = var.instance_id }

  actions_enabled = var.actions_enabled
  alarm_actions   = [local.critical_topic_arn]
  ok_actions      = [local.critical_topic_arn]

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-cpu-high" })
}

# Sustained high memory. Unlike disk, both OS measure "in use" the same direction.
resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.environment}-${var.instance_name}-memory-high"
  namespace           = "CWAgent"
  metric_name         = var.os_family == "windows" ? "Memory % Committed Bytes In Use" : "mem_used_percent"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 90
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = merge(
    local.base_dimensions,
    var.os_family == "windows" ? { objectname = "Memory" } : {}
  )

  actions_enabled = var.actions_enabled
  alarm_actions   = [local.critical_topic_arn]
  ok_actions      = [local.critical_topic_arn]

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-memory-high" })
}
