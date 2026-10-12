locals {
  critical_topic_arn = coalesce(var.critical_topic_arn, var.routine_topic_arn)

  base_dimensions = {
    InstanceId   = var.instance_id
    ImageId      = var.image_id
    InstanceType = var.instance_type
  }

  disks_by_label = { for d in var.disks : d.label => d }

  dso_actions = compact([var.dso_topic_arn])

  # Windows needs exe, not pattern (pattern matches nothing there). Metric name
  # differs too, a space instead of an underscore. Confirmed live.
  procstat_match_key   = var.os_family == "windows" ? "exe" : "pattern"
  procstat_metric_name = var.os_family == "windows" ? "procstat_lookup pid_count" : "procstat_lookup_pid_count"
  services_by_name     = { for s in var.services : s.name => s }

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
  alarm_actions   = concat([each.value.threshold.topic_arn], local.dso_actions)
  ok_actions      = concat([each.value.threshold.topic_arn], local.dso_actions)

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
  alarm_actions   = concat([local.critical_topic_arn], local.dso_actions)
  ok_actions      = concat([local.critical_topic_arn], local.dso_actions)

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
  alarm_actions   = concat([local.critical_topic_arn], local.dso_actions)
  ok_actions      = concat([local.critical_topic_arn], local.dso_actions)

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
  alarm_actions   = concat([local.critical_topic_arn], local.dso_actions)
  ok_actions      = concat([local.critical_topic_arn], local.dso_actions)

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-memory-high" })
}

# Additive config layer. Doesn't touch the instance's existing disk/mem config.
resource "aws_ssm_parameter" "procstat_config" {
  count = length(var.services) > 0 ? 1 : 0

  name = "/cloudwatch-agent/${var.environment}-${var.instance_name}/procstat"
  type = "String"
  value = jsonencode({
    metrics = {
      metrics_collected = {
        procstat = [
          for s in var.services : merge(
            { (local.procstat_match_key) = coalesce(s.pattern, s.exe) },
            { measurement = ["pid_count"] }
          )
        ]
      }
    }
  })

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-procstat-config" })
}

resource "aws_ssm_association" "procstat_config" {
  count = length(var.services) > 0 ? 1 : 0

  name = "AmazonCloudWatch-ManageAgent"

  targets {
    key    = "InstanceIds"
    values = [var.instance_id]
  }

  parameters = {
    action                        = "configure (append)"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.procstat_config[0].name
    optionalRestart               = "yes"
  }

  tags = var.tags

  # The parameter name never changes, only its value. Without this, a services edit
  # updates the parameter but never re-runs append-config on the instance.
  lifecycle {
    replace_triggered_by = [aws_ssm_parameter.procstat_config[0].value]
  }
}

# Deleting the parameter/association alone doesn't undo what's on the instance.
resource "null_resource" "procstat_cleanup" {
  count = length(var.services) > 0 ? 1 : 0

  triggers = {
    instance_id = var.instance_id
    param_name  = aws_ssm_parameter.procstat_config[0].name
  }

  provisioner "local-exec" {
    when    = destroy
    command = "aws ssm send-command --instance-ids ${self.triggers.instance_id} --document-name AmazonCloudWatch-ManageAgent --parameters action='configure (remove)',mode=ec2,optionalConfigurationSource=ssm,optionalConfigurationLocation=${self.triggers.param_name},optionalRestart=yes"
  }
}

# One alarm per named service. Maximum, not Minimum, so a brief blip doesn't trip it.
resource "aws_cloudwatch_metric_alarm" "service_down" {
  for_each = local.services_by_name

  alarm_name          = "${var.environment}-${var.instance_name}-${each.key}-down"
  namespace           = "CWAgent"
  metric_name         = local.procstat_metric_name
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "LessThanThreshold"

  dimensions = merge(
    local.base_dimensions,
    { (local.procstat_match_key) = coalesce(each.value.pattern, each.value.exe) },
    { pid_finder = "native" }
  )

  actions_enabled = var.actions_enabled
  alarm_actions   = concat([local.critical_topic_arn], local.dso_actions)
  ok_actions      = concat([local.critical_topic_arn], local.dso_actions)

  tags = merge(var.tags, { Name = "${var.environment}-${var.instance_name}-${each.key}-down" })
}
