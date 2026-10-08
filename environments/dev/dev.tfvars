aws_region = "us-east-1"

# CloudWatch alerts: dev is NON-PROD tier, routine channel only, email to WinOpsDL.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
}

# Disk alarms, primary disk per instance. Linux: disk_used_percent, alarm high.
# Windows: LogicalDisk % Free Space, alarm low.
cloudwatch_alerts_alarms = [
  {
    name                 = "sbap01-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sbap01-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sbap01-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # sbap01 also has a real /home volume, separate from /.
  {
    name                 = "sbap01-home-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sbap01-home-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sbap01-home-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # emts01 also has a real D: data volume (labeled "App"), separate from C:.
  {
    name                 = "emts01-d-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "D:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-d-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "D:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-d-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c", instance = "D:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts02-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0334e1242e1ceff4e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts02-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0334e1242e1ceff4e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts02-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0334e1242e1ceff4e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts03-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-04cf9c488ce8c1a1e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts03-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-04cf9c488ce8c1a1e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts03-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-04cf9c488ce8c1a1e", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # Reachability (ping) alarms. EC2 status check, no agent needed.
  {
    name                 = "sbap01-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-04bc18689d5d8a9c5" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts01-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0ef056ef9a04e2c6c" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts02-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0334e1242e1ceff4e" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "emts03-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-04cf9c488ce8c1a1e" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
]

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "dev"
  "pbs:billing:product"     = "dev"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}