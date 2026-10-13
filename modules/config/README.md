# AWS Config EC2 Compliance Module

Monitor whether active EC2 instances in the current AWS Region have CloudWatch alarms for **CPU**, **memory**, and **disk** metrics. This module uses AWS 
Config to detect non-compliance and can optionally send alerts via SNS.

## Quick Start

**For production with alerts:**
```hcl
module "config" {
  source = "../../modules/config"

  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["routine"]
  create_notification_topic = false
  create_recorder           = false
  
  tags = var.tags
}
```

**For testing without alerts:**
```hcl
module "config" {
  source = "../../modules/config"

  enable_notifications = false
  create_recorder      = false
  
  tags = var.tags
}
```

## How It Works

1. **AWS Config Recorder** captures EC2 instance state (if enabled)
2. **Config Rule** triggers on a schedule (default: hourly)
3. **Lambda (`ec2_alarm_check`)** evaluates each instance:
   - Lists all running/stopped/stopping/pending instances
   - Queries CloudWatch for alarms matching instance ID
   - Checks if required metrics are covered
4. **Config Service** stores compliance results
5. **EventBridge** detects `NON_COMPLIANT` events (if notifications enabled)
6. **SNS Topic** routes alerts to subscribed channels (if notifications enabled)

## Required Alarms

Each instance must have **at least one alarm** for each metric:

| Metric | Namespace | Default Name | Source |
|--------|-----------|--------------|--------|
| CPU | `AWS/EC2` | `CPUUtilization` | Built-in EC2 metrics |
| Memory | `CWAgent` | `mem_used_percent` | CloudWatch Agent |
| Disk | `CWAgent` | `disk_used_percent` | CloudWatch Agent |

Alarms can use any of the default metric names OR custom names (see "Metric Configuration" below).

## Usage Modes

### Mode 1: Shared Notifications (Production)

Route Config alerts to the same SNS topic as CloudWatch alarms (unified alerting).

```hcl
module "cloudwatch_alerts" {
  source = "../../modules/cloudwatch-alerts"
  
  name                  = "prod"
  notification_channels = {
    routine  = { email_subscriptions = ["ops@company.com"] }
    critical = { email_subscriptions = ["ops@company.com"], slack_webhook_secret_name = "prod-slack" }
  }
  
  tags = var.tags
}

module "config" {
  source = "../../modules/config"

  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["routine"]
  create_notification_topic = false
  create_recorder           = false

  tags = var.tags
}
```

**What happens:**
- ✅ Uses existing "routine" SNS topic
- ✅ Config compliance alerts go to same channel as CloudWatch alarms
- ✅ Single notification channel for all infrastructure alerts

### Mode 2: Dedicated Notifications (Dev/Test)

Create a standalone SNS topic just for Config alerts.

```hcl
module "config" {
  source = "../../modules/config"

  alert_email               = "dev-alerts@company.com"
  create_notification_topic = true
  create_recorder           = true

  tags = var.tags
}
```

**What happens:**
- ✅ Creates SNS topic: `ec2-required-cloudwatch-alarms-alerts`
- ✅ Subscribes `dev-alerts@company.com` (requires manual email confirmation)
- ✅ Creates Config recorder (if not already in account)

### Mode 3: Compliance-Only Testing

Deploy compliance checking without sending alerts. Useful for testing before enabling notifications.

```hcl
module "config" {
  source = "../../modules/config"

  enable_notifications = false
  create_recorder      = false

  tags = var.tags
}
```

**What happens:**
- ✅ Config rule evaluates compliance
- ✅ Results visible in AWS Config console
- ❌ No SNS topic created
- ❌ No alerts sent
- Switch `enable_notifications = true` later to enable alerts

### Mode 4: Bring Your Own Topic

Use a pre-existing SNS topic (e.g., from another module).

```hcl
module "config" {
  source = "../../modules/config"

  notification_topic_arn    = "arn:aws:sns:us-east-1:123456789012:my-alerts"
  create_notification_topic = false

  tags = var.tags
}
```

**What happens:**
- ✅ Routes alerts to your provided SNS topic
- ✅ No topic or subscriptions created by this module

## Input Variables

### Notification Control

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `enable_notifications` | bool | `true` | Send alerts on non-compliance. Set `false` for testing. |
| `create_notification_topic` | bool | `false` | Create a dedicated SNS topic (requires `alert_email`). |
| `notification_topic_arn` | string | `null` | SNS topic ARN for alerts (when not creating a topic). |
| `alert_email` | string | `null` | Email to subscribe to dedicated topic (only used when `create_notification_topic = true`). |

**Validation:**
- If `enable_notifications = true` and `create_notification_topic = true`: require `alert_email`
- If `enable_notifications = true` and `create_notification_topic = false`: require `notification_topic_arn`
- If `enable_notifications = false`: no requirements

### Infrastructure Control

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_recorder` | bool | `true` | Create AWS Config recorder. Set `false` if one already exists in account. |
| `rule_name` | string | `"ec2-required-cloudwatch-alarms"` | Name for Config rule and related resources. |
| `evaluation_frequency` | string | `"One_Hour"` | How often Config evaluates: `One_Hour`, `Three_Hours`, `Six_Hours`, `Twelve_Hours`, `TwentyFour_Hours` |
| `config_bucket_name_prefix` | string | `"aws-config-bucket"` | S3 bucket prefix for Config snapshots (account ID and region auto-appended). |
| `config_snapshot_frequency` | string | `"Six_Hours"` | How often Config takes snapshots: `One_Hour`, `Three_Hours`, `Six_Hours`, `Twelve_Hours`, `TwentyFour_Hours` |

### Lambda & Metrics

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `lambda_artifact_s3_bucket` | string | `null` | S3 bucket for Lambda deployment package. If `null`, one is created. |
| `lambda_artifact_s3_prefix` | string | `"lambda-artifacts/config"` | S3 key prefix for Lambda zip (content hash auto-appended). |
| `required_metrics` | map(list(string)) | See below | Map of check type → list of metric identifiers. |
| `require_alarm_actions` | bool | `true` | Only count alarms that have actions enabled and configured. |
| `tags` | map(string) | `{}` | Tags applied to all resources. |

### Metric Configuration

`required_metrics` defines what alarms instances must have:

```hcl
required_metrics = {
  cpu    = ["AWS/EC2:CPUUtilization"]
  memory = ["CWAgent:mem_used_percent", "CWAgent:Memory % Committed Bytes In Use"]
  disk   = ["CWAgent:disk_used_percent", "CWAgent:LogicalDisk % Free Space"]
}
```

**Metric identifier format:**
- `"MetricName"` — Uses default namespace (AWS/EC2 for cpu, CWAgent for memory/disk)
- `"Namespace:MetricName"` — Explicit namespace

An instance is compliant if it has an alarm for **any** metric in each check's list.

## How Compliance Evaluation Works

The Lambda evaluator checks each instance:

1. **Lists all EC2 instances** in running/stopped/stopping/pending states
2. **Queries CloudWatch alarms** and extracts metrics with InstanceId dimensions
3. **Matches alarms to instances:**
   - Extracts (namespace, metric_name) from each alarm
   - Compares to required metrics
   - Namespace matters: `AWS/EC2:CPUUtilization` ≠ `Custom:CPUUtilization`
4. **Evaluates compliance:**
   - Instance needs **at least one alarm** for each check (cpu, memory, disk)
   - Missing any check → `NON_COMPLIANT`
   - Has all checks → `COMPLIANT`
5. **Reports to Config:**
   - Stores compliance state
   - EventBridge triggers on changes (if notifications enabled)

### Example

Instance `i-1234567890abcdef0` alarms:
- `My-CPU-Alarm` on `AWS/EC2:CPUUtilization` with dimension `InstanceId=i-1234567890abcdef0`
- `My-Memory-Alarm` on `CWAgent:mem_used_percent` with dimension `InstanceId=i-1234567890abcdef0`
- (no disk alarm)

**Result:** `NON_COMPLIANT` — missing disk alarm

## Testing the Lambda

Use the Lambda test console with this event:

```json
{
  "invokingEvent": "{\"notificationCreationTime\": \"2026-10-13T14:30:00Z\"}",
  "resultToken": "TESTMODE",
  "configRuleName": "ec2-required-cloudwatch-alarms"
}
```

**With `resultToken: "TESTMODE"`:**
- Lambda runs but doesn't submit to Config
- See evaluation logic in logs only
- Safe for testing

## Troubleshooting

### Alarms not detected

- **Check alarm actions:** If `require_alarm_actions = true` (default), alarms must have at least one action configured and actions enabled
- **Verify InstanceId dimension:** Alarm must include `Dimensions: [{ Name: "InstanceId", Value: "i-..." }]`
- **Check metric namespace:** If using custom namespaces, ensure they match `required_metrics` config
- **Confirm alarm state:** CloudWatch only reports alarms in `ALARM`, `OK`, or `INSUFFICIENT_DATA` states

### Config rule not evaluating

- **Check recorder status:** `aws configservice describe-configuration-recorder-status`
- **View Lambda logs:** CloudWatch Logs group `/aws/lambda/ec2-required-cloudwatch-alarms`
- **Verify IAM permissions:** Lambda role needs `ec2:DescribeInstances`, `cloudwatch:DescribeAlarms`, `config:PutEvaluations`

### Alerts not received

- **Email subscriptions:** Check spam folder and confirm SNS subscription
- **External topic:** Verify SNS topic policy allows EventBridge (`events.amazonaws.com`) to publish
- **Check EventBridge rule:** `aws events describe-rule --name ec2-required-cloudwatch-alarms-noncompliant`

### "No recorder" error

If you get "Recorder not running" or similar:
- A pre-existing recorder in your account is already managing Config state
- Set `create_recorder = false` to avoid conflicts
- Review the Terraform plan and migrate ownership of the recorder and its dependencies before changing `create_recorder`; do not remove only the recorder
  from state

## Architecture Details

### Why Namespace-Aware Matching?

The evaluator distinguishes metrics by **both namespace and name**:
- ✅ Instance with alarm on `AWS/EC2:CPUUtilization` satisfies cpu check
- ❌ Instance with alarm on `Custom:CPUUtilization` does NOT satisfy cpu check

This prevents false positives where custom metrics with identical names could incorrectly mark instances as compliant.

### Why No SNS Topic Policy in Config Module?

Within the same AWS account:
- CloudWatch alarms have built-in permission to publish to SNS
- EventBridge also has service-level permission in same-account scenarios
- Resource policies (topic policies) are **only needed for cross-account access**

The `cloudwatch-alerts` module manages topic policies for all its managed topics, granting both CloudWatch and EventBridge permission to publish.

### S3-Based Lambda Deployment

Lambda code is uploaded to S3 with **content-addressed naming**:
```
s3://<bucket>/<prefix>/ec2_alarm_check-<sha256>.zip
```

Benefits:
- ✅ Avoids conflicts in CI/CD with concurrent `terraform apply` runs
- ✅ Automatically updates when source code changes
- ✅ Old versions retained for rollback (if S3 versioning enabled)

## Cost Estimate

- **AWS Config:** ~$0.10/rule/month (hourly evaluation)
- **Lambda:** ~$0.20/month (1,000 invocations/month × ~1s each)
- **S3:** <$0.01/month (small snapshots and artifacts)
- **SNS:** Varies by notification channels

**Total:** $0.50–$5/month per environment

## Examples

### Dev: Standalone with email
```hcl
module "config" {
  source = "../../modules/config"

  alert_email               = "dev@company.com"
  create_notification_topic = true
  create_recorder           = true

  required_metrics = {
    cpu    = ["AWS/EC2:CPUUtilization"]
    memory = ["CWAgent:mem_used_percent"]
    disk   = ["CWAgent:disk_used_percent"]
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Staging: Shared routine alerts
```hcl
module "config" {
  source = "../../modules/config"

  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["routine"]
  create_notification_topic = false
  create_recorder           = false

  tags = var.tags
}
```

### Production: Shared critical alerts
```hcl
module "config" {
  source = "../../modules/config"

  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["critical"]
  create_notification_topic = false
  create_recorder           = false

  evaluation_frequency = "Six_Hours"  # Less frequent evaluation
  tags                 = var.tags
}
```

## Related Modules

- **`cloudwatch-alerts`**: Creates and manages SNS topics for CloudWatch and Config alerts
- **`backup`**: Protects instance data
