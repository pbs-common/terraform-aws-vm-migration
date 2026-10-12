# Instance Alarms Module

This module creates the standard disk, reachability, CPU, memory, and service-down alarms for one EC2 instance, wired to notification channels created by the `cloudwatch-alerts` module. One module call per instance, placed next to that instance's own `aws_instance`/module block.

## Alarms created

- **Disk** - one 8%/4%/0%-free alarm set per entry in `disks` (routine/critical/critical).
- **Reachability** - one EC2 status check alarm, always routed to the critical channel.
- **CPU and memory** - one alarm each, unconditional (no input needed), 90% sustained for 15 minutes, routed to the critical channel.
- **Service-down** - one alarm per entry in `services`, via CWAgent's procstat plugin. Routed to the critical channel, same as reachability.

`critical_topic_arn` defaults to `routine_topic_arn` for environments with only one channel. Every alarm also notifies `dso_topic_arn` if set.

## Usage

```hcl
module "dc1_alarms" {
  source = "./modules/instance-alarms"

  environment   = "ad"
  instance_name = "dc1"
  instance_id   = module.dc1.instance_id
  image_id      = module.dc1.ami_id
  instance_type = module.dc1.instance_type
  os_family     = "windows"
  disks         = [{ drive_letter = "C:" }]
  services = [
    { name = "ad-core-services", exe = "lsass.exe" },
  ]

  routine_topic_arn  = module.cloudwatch_alerts.sns_topic_arns["routine"]
  critical_topic_arn = module.cloudwatch_alerts.sns_topic_arns["critical"]
  dso_topic_arn      = var.dso_topic_arn
}
```

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| disks | Disks to alarm on, each gets the standard 8/4/0 free-percent alarm set. Windows: set `drive_letter` (e.g. "C:"). Linux: set `path`/`device`/`fstype`. `label` suffixes the alarm name (e.g. "home" for /home) - leave empty for the primary disk. | `list(object({...}))` | n/a | yes |
| environment | Environment name prefix for alarm names, e.g. "ad" or "staging". | `string` | n/a | yes |
| image_id | The instance's AMI ID. Required as a CWAgent metric dimension. | `string` | n/a | yes |
| instance_id | The instance's real ID - reference its `aws_instance`/module resource directly, don't hardcode. | `string` | n/a | yes |
| instance_name | Short name for this instance, used in alarm names, e.g. "dc1". | `string` | n/a | yes |
| instance_type | The instance's type. Required as a CWAgent metric dimension. | `string` | n/a | yes |
| os_family | "windows" or "linux". Picks the CWAgent metric name, dimension shape, and comparison direction - Windows measures free space, Linux measures used space. | `string` | n/a | yes |
| routine_topic_arn | SNS topic ARN for routine-severity notifications (disk at 8% free). | `string` | n/a | yes |
| actions_enabled | Whether these alarms notify on state change. Set false for an initial rollout so alarms settle into real state without firing. | `bool` | `true` | no |
| critical_topic_arn | SNS topic ARN for critical-severity notifications (disk at 4%/0% free, unreachable). Defaults to `routine_topic_arn` for environments with no separate critical channel. | `string` | `null` | no |
| dso_topic_arn | Extra SNS topic every alarm also notifies, for DSO's org-wide alerting. No default. Set via TF_VAR_EXTRAS, not committed. Null disables it. | `string` | `null` | no |
| services | Named services to alarm on if the process stops running, via CWAgent's procstat plugin. Linux: pattern (matches the command line). Windows: exe (exact name). Pattern doesn't work there. Exactly one of pattern/exe. | `list(object({...}))` | `[]` | no |
| tags | Tags applied to each alarm, merged with an automatic Name tag. | `map(string)` | `{}` | no |

## Outputs

No outputs.
