aws_region = "us-east-1"

# CloudWatch alerts: ad is PROD tier. Two channels: routine (email, disk at 8%
# free) and critical (email, Slack, PagerDuty, for ping/service down and disk at 4%/0%
# free). Slack webhook secret and PagerDuty key are both live.
cloudwatch_alerts_notification_channels = {
  routine = {
    email_subscriptions = ["winopsdl@pbs.org"]
  }
  critical = {
    email_subscriptions                  = ["winopsdl@pbs.org"]
    slack_webhook_secret_arn             = "arn:aws:secretsmanager:us-east-1:064271145854:secret:ad-cloudwatch-alerts-slack-webhook-qS2EWR"
    pagerduty_integration_key_secret_arn = "arn:aws:secretsmanager:us-east-1:064271145854:secret:ad-cloudwatch-alerts-pagerduty-key-aPOB6R"
  }
}

# dc1/dc2 disk and reachability alarms. Windows: LogicalDisk % Free Space, alarm low.
# Reachability: EC2 status check, no agent needed.
cloudwatch_alerts_alarms = [
  {
    name                 = "dc1-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c3f94aab892dc2aa", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "dc1-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c3f94aab892dc2aa", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "dc1-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-0c3f94aab892dc2aa", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "dc1-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed"
    dimensions           = { InstanceId = "i-0c3f94aab892dc2aa" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "dc2-disk-free-8"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-092b297b4d11cdb21", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 8
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "routine"
  },
  {
    name                 = "dc2-disk-free-4"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-092b297b4d11cdb21", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 4
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "dc2-disk-free-0"
    namespace            = "CWAgent"
    metric_name          = "LogicalDisk % Free Space"
    dimensions           = { InstanceId = "i-092b297b4d11cdb21", instance = "C:", objectname = "LogicalDisk" }
    statistic            = "Minimum"
    threshold            = 0
    comparison_operator  = "LessThanOrEqualToThreshold"
    notification_channel = "critical"
  },
  {
    name                 = "dc2-unreachable"
    namespace            = "AWS/EC2"
    metric_name          = "StatusCheckFailed"
    dimensions           = { InstanceId = "i-092b297b4d11cdb21" }
    period               = 300
    evaluation_periods   = 1
    threshold            = 1
    comparison_operator  = "GreaterThanOrEqualToThreshold"
    notification_channel = "critical"
  },
]

# Golden AMI: AD-DS/DNS installed, not promoted, sysprepped. Built manually.
golden_ami_id = "ami-038905f9eb15c1313"

private_subnet_name_prefix = "pbs-sharedtools-useast1-subnet-private"
dc1_availability_zone      = "us-east-1a"
dc2_availability_zone      = "us-east-1b"

instance_type    = "t3.large"
root_volume_size = 100

tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "ad"
  "pbs:billing:product"     = "active-directory"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}

# One SG per prefix list. 20 AD ports x CIDRs must stay under the 100-rule
# quota: on_prem 2x20=40, aws_shared 1x20=20, azure 4x20=80.
ad_security_groups = {
  on_prem = {
    groups = {
      # soc + cchq
      on_prem = ["10.168.0.0/16", "10.68.0.0/16"]
    }
  }
  aws_shared = {
    groups = {
      aws_shared = ["10.202.0.0/16"]
    }
  }
  azure = {
    groups = {
      # 10.164.0.0/16 and 10.64.0.0/16 are the old overflow/overflow2 CIDRs, azure too.
      azure = ["10.190.0.0/16", "10.191.0.0/16", "10.164.0.0/16", "10.64.0.0/16"]
    }
  }
}

key_name = null

# MGN Configuration
environment_name            = "ad"
mgn_staging_az              = "us-east-1a"
mgn_staging_subnet_cidr     = "172.31.100.0/24"
mgn_create_internet_gateway = false
mgn_internet_gateway_id     = null
mgn_source_vpc_cidr_blocks  = ["10.0.0.0/8"]
mgn_cross_account_role_arns = []
enable_mgn_ebs_encryption   = true
mgn_kms_key_arn             = null

# Common tags for MGN resources
common_tags = {
  "map-migrated"            = "mig5T578AWUOW"
  "pbs:billing:environment" = "ad"
  "pbs:billing:product"     = "active-directory"
  "pbs:billing:owner"       = "infra"
  "repo"                    = "https://github.com/pbs-common/terraform-aws-vm-migration.git"
}
