aws_region = "us-east-1"

# CloudWatch alerts: workspaces is NON-PROD tier, routine channel only, email to WinOpsDL.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
}

# Disk alarms, primary disk per instance. Linux: disk_used_percent, alarm high.
# Windows: LogicalDisk % Free Space, alarm low.
cloudwatch_alerts_alarms = [
  {
    name                 = "ghsd01-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-062c6c56e0ea43a52", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd01-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-062c6c56e0ea43a52", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd01-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-062c6c56e0ea43a52", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/", device = "mapper/rhel-root", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # sits01 also has a real /home volume, separate from /.
  {
    name                 = "sits01-home-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-home-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-home-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6", path = "/home", device = "mapper/rhel-home", fstype = "xfs" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev10-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0745c6a50a22b3970", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev10-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0745c6a50a22b3970", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev10-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0745c6a50a22b3970", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-kt-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-05358ac8ae6ae3398", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-kt-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-05358ac8ae6ae3398", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-kt-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-05358ac8ae6ae3398", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # esdev-brian also has a real E: data volume, separate from C:.
  {
    name                 = "esdev-brian-e-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-e-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-e-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-sm-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-03cd76dd517b2efb6", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-sm-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-03cd76dd517b2efb6", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-sm-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-03cd76dd517b2efb6", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-bb-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-037e76172f90efc2d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-bb-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-037e76172f90efc2d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-bb-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-037e76172f90efc2d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-zc-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-03d447ddfcf97efe7", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-zc-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-03d447ddfcf97efe7", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-zc-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-03d447ddfcf97efe7", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd04-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-031ddd298cf491c67", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 92
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd04-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-031ddd298cf491c67", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 96
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd04-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "disk_used_percent"
    dimensions           = { InstanceId = "i-031ddd298cf491c67", path = "/", device = "mapper/ubuntu--vg-ubuntu--lv", fstype = "ext4" }
    statistic            = "Maximum"
    threshold            = 100
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-mr-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0882b12d32667c7ee", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-mr-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0882b12d32667c7ee", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-mr-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0882b12d32667c7ee", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-ld-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-069a3f4cdaec8c82a", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-ld-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-069a3f4cdaec8c82a", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-ld-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-069a3f4cdaec8c82a", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # esdev12 also has a real E: data volume, separate from C:.
  {
    name                 = "esdev12-e-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-e-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-e-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # esdev08 also has a real E: data volume, separate from C:.
  {
    name                 = "esdev08-e-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-e-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-e-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d", instance = "E:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sid1-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-00c1e14ce9114b57c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sid1-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-00c1e14ce9114b57c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sid1-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-00c1e14ce9114b57c", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-chex-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-02913429a0e270b18", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-chex-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-02913429a0e270b18", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-chex-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-02913429a0e270b18", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "devops-app1-dev-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0d9ab8addd6e1a4db", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "devops-app1-dev-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0d9ab8addd6e1a4db", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "devops-app1-dev-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0d9ab8addd6e1a4db", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  # Reachability (ping) alarms. EC2 status check, no agent needed.
  {
    name                 = "ghsd01-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-062c6c56e0ea43a52" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sits01-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0f15f3836d730abb6" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev10-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0745c6a50a22b3970" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-kt-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-05358ac8ae6ae3398" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-brian-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0e71029bbc740a4b2" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-sm-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-03cd76dd517b2efb6" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-bb-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-037e76172f90efc2d" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-zc-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-03d447ddfcf97efe7" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ghsd04-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-031ddd298cf491c67" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-mr-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0882b12d32667c7ee" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "ngws-ld-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-069a3f4cdaec8c82a" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev12-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-078edb8241c6df4f2" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev08-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0c2fd56636c99ff1d" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "sid1-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-00c1e14ce9114b57c" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "esdev-chex-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-02913429a0e270b18" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "devops-app1-dev-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed_System"
    dimensions           = { InstanceId = "i-0d9ab8addd6e1a4db" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "routine"
  },
]

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "workspaces"
  "pbs:billing:product"     = "workspaces"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}