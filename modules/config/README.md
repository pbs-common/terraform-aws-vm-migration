# AWS Config EC2 Compliance Module

This module enforces that **every EC2 instance in your account has CloudWatch alarms** for CPU, memory, and disk metrics. It uses AWS Config to periodically check compliance and sends alerts when instances are non-compliant.

## How It Works

```
┌─────────────────┐
│  AWS Config     │
│  Recorder       │  Continuously monitors EC2 instances
└────────┬────────┘
         │ evaluates
         ▼
┌─────────────────┐
│  Config Rule    │  Scheduled (hourly, 3-hourly, etc.)
└────────┬────────┘
         │ invokes
         ▼
┌─────────────────────────────┐
│  Lambda: ec2_alarm_check    │  Checks each instance for required alarms
│  - Queries EC2 instances    │
│  - Queries CloudWatch       │  • CPU (AWS/EC2:CPUUtilization)
│  - Evaluates compliance     │  • Memory (CWAgent:mem_used_percent)
└────────┬────────────────────┘  • Disk (CWAgent:disk_used_percent)
         │ reports
         ▼
┌──────────────────────────┐
│  Config Evaluator        │  Compliance: COMPLIANT / NON_COMPLIANT
│  (Config service)        │
└────────┬─────────────────┘
         │ triggers on compliance change
         ▼
┌──────────────────────────┐
│  EventBridge Rule        │  Filters for NON_COMPLIANT events
└────────┬─────────────────┘
         │ sends to
         ▼
┌──────────────────────────┐
│  SNS Topic               │  Email, Slack, PagerDuty, etc.
│  (alerts)                │
└──────────────────────────┘
```

## Architecture

### Components Created

#### AWS Config Infrastructure
- **Recorder** (optional): Continuously records AWS resource changes. Only created if `create_recorder = true`. You may already have one in your account.
- **Delivery Channel**: Sends Config snapshots to S3 for audit.
- **Config Rule**: Periodic evaluation (e.g., hourly) that invokes the Lambda.

#### Lambda Evaluator
- **Function**: `ec2_alarm_check.py` — Python code that:
  1. Lists all EC2 instances (in `running`, `stopped`, `stopping`, `pending` states)
  2. Queries CloudWatch alarms
  3. Checks if each instance has required alarms for all metrics
  4. Reports compliance back to Config

- **Storage**: Lambda code is zipped and uploaded to S3 with content-based naming to avoid conflicts during concurrent runs.
- **IAM Role**: Grants Lambda permissions to read EC2/CloudWatch and write Config results.

#### Alerting
- **EventBridge Rule**: Listens for Config compliance changes (`NON_COMPLIANT` events)
- **SNS Topic**: Receives alerts and routes to configured destinations (email, Slack, PagerDuty, etc.)
- **Routing**: Alerts go to the SNS topic specified by `notification_topic_arn` (or created locally if `create_notification_topic = true`)

## Configuration Modes

### Mode 1: With External SNS Topic (Recommended for Staging/Prod)

Use this when you want Config alerts to go to the **same channels as CloudWatch alarms** (e.g., a shared "routine" or "critical" topic).

```hcl
module "config" {
  source = "../../modules/config"

  # Point to existing SNS topic created by cloudwatch-alerts module
  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["routine"]
  create_notification_topic = false
  create_recorder           = false  # Recorder already exists in account
  
  tags = var.tags
}
```

**No SNS topic is created by this module.** The config module only:
- Creates the Config evaluator (rule + Lambda)
- Routes alerts via EventBridge to the external topic
- The `cloudwatch-alerts` module manages the topic and all permissions

### Mode 2: With Dedicated SNS Topic (Recommended for Dev)

Create a standalone SNS topic with email subscriptions just for Config alerts.

```hcl
module "config" {
  source = "../../modules/config"

  alert_email               = "alerts@example.com"
  create_notification_topic = true
  create_recorder           = true  # Create recorder if not already in account
  
  tags = var.tags
}
```

**This creates:**
- Dedicated SNS topic (name: `ec2-required-cloudwatch-alarms-alerts`)
- Email subscription to `alerts@example.com` (requires manual confirmation)
- Config recorder (if not already configured)

### Mode 3: Bring Your Own Topic (Advanced)

If you have a pre-existing SNS topic elsewhere, provide its ARN directly.

```hcl
module "config" {
  source = "../../modules/config"

  notification_topic_arn    = "arn:aws:sns:us-east-1:123456789012:my-alerts"
  create_notification_topic = false
  
  tags = var.tags
}
```

## Inputs

### Required When `create_notification_topic = true`
- **`alert_email`** (string): Email to receive alerts. Must confirm SNS subscription after deploy.

### Required When `create_notification_topic = false`
- **`notification_topic_arn`** (string): SNS topic ARN for alerts. No subscription management by this module.

### Optional
- **`create_notification_topic`** (bool, default: `true`): Whether to create a dedicated SNS topic for alerts.
- **`create_recorder`** (bool, default: `true`): Whether to create AWS Config recorder. Set to `false` if one already exists.
- **`rule_name`** (string, default: `"ec2-required-cloudwatch-alarms"`): Name for the Config rule and related resources.
- **`evaluation_frequency`** (string, default: `"One_Hour"`): How often Config runs the check. Options: `One_Hour`, `Three_Hours`, `Six_Hours`, `Twelve_Hours`, `TwentyFour_Hours`.
- **`config_bucket_name_prefix`** (string, default: `"aws-config-bucket"`): Prefix for Config snapshot S3 bucket. (Account ID and region auto-appended.)
- **`config_snapshot_frequency`** (string, default: `"Six_Hours"`): How often Config snapshots are taken.
- **`lambda_artifact_s3_bucket`** (string, default: `null`): S3 bucket for Lambda code. If not provided, one is created.
- **`lambda_artifact_s3_prefix`** (string, default: `"lambda-artifacts/config"`): S3 key prefix for Lambda zip.
- **`required_metrics`** (map, default: See below): Map of check type → list of metric identifiers.
- **`require_alarm_actions`** (bool, default: `true`): If `true`, ignore alarms with actions disabled or no action configured.
- **`tags`** (map(string), default: `{}`): Tags applied to all created resources.

### Metric Configuration

`required_metrics` is a map of check type → list of acceptable metric identifiers:

```hcl
required_metrics = {
  cpu    = ["AWS/EC2:CPUUtilization"]
  memory = ["CWAgent:mem_used_percent", "CWAgent:Memory % Committed Bytes In Use"]
  disk   = ["CWAgent:disk_used_percent", "CWAgent:LogicalDisk % Free Space"]
}
```

**Metric identifier format:**
- **`"MetricName"`** — Uses default namespace (AWS/EC2 for cpu, CWAgent for memory/disk)
- **`"Namespace:MetricName"`** — Explicit namespace (recommended for clarity)

The evaluator accepts **any** of the listed metrics. For example, if `"disk"` has both `disk_used_percent` and `LogicalDisk % Free Space`, an instance is compliant if it has an alarm for *either* metric.

## Validation

The module enforces:
- **At least one notification destination**: If both `notification_topic_arn` and `alert_email` are null, Terraform fails with a clear error. This prevents silent configuration where alerts go nowhere.

## Outputs

Currently, none. The module is designed to be self-contained. Alerts are routed via SNS subscriptions defined separately (either in this module for Mode 2, or in `cloudwatch-alerts` for Mode 1).

## Namespace-Aware Metric Matching

The Lambda evaluator is **namespace-aware**. It distinguishes metrics by both namespace AND name:

- ✅ Instance with alarm on `AWS/EC2:CPUUtilization` satisfies `cpu` requirement
- ❌ Instance with alarm on `Custom:CPUUtilization` does NOT satisfy `cpu` requirement (different namespace)

This prevents false positives where a custom-namespace metric with an identical name could incorrectly mark an instance as compliant.

## S3-Based Lambda Deployment

Lambda code is uploaded to S3 with **content-addressed naming** (hash of source code included in the key):

```
s3://<bucket>/<prefix>/ec2_alarm_check-<sha256>.zip
```

This design:
- ✅ Avoids conflicts in CI/CD with concurrent `terraform apply` runs
- ✅ Automatically updates when source code changes
- ✅ Keeps old versions for rollback (if S3 versioning is enabled)

## State and Compliance

Once deployed:
1. **Config Recorder** continuously captures EC2 state changes
2. **Config Rule** runs on schedule (default: hourly)
3. **Lambda** evaluates each instance and reports compliance to Config
4. **EventBridge** detects compliance changes and sends alerts via SNS

**To manually re-evaluate** (e.g., after adding alarms):
```bash
aws configservice start-config-rules-evaluation --config-rule-names ec2-required-cloudwatch-alarms
```

## Troubleshooting

### Alarms not detected
- Check that alarm **actions are enabled** (`require_alarm_actions = true` by default means actions must be configured)
- Verify alarm metrics have the correct **InstanceId dimension**
- Confirm metric **namespace** matches `required_metrics` configuration

### Config rule not evaluating
- Check recorder is running: `aws configservice describe-configuration-recorder-status`
- Check Lambda logs: CloudWatch Logs group `/aws/lambda/ec2-required-cloudwatch-alarms`
- Verify Lambda IAM role has `ec2:Describe*` and `cloudwatch:DescribeAlarms` permissions

### Alerts not received
- For email: Confirm SNS subscription in mailbox (check spam)
- For external topic: Verify EventBridge rule is targeting the correct SNS topic ARN
- Check SNS topic policy allows EventBridge to publish (managed by `cloudwatch-alerts` module if used)

## Examples

### Dev: Standalone with email
```hcl
module "config" {
  source = "../../modules/config"

  alert_email     = "dev-alerts@company.com"
  create_recorder = true

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Staging: Shared topic with CloudWatch alerts
```hcl
module "cloudwatch_alerts" {
  source = "../../modules/cloudwatch-alerts"
  
  name                  = "staging"
  notification_channels = {
    routine  = { email_subscriptions = ["ops@company.com"] }
    critical = { email_subscriptions = ["ops@company.com"], slack_webhook_secret_name = "staging-slack" }
  }
  
  tags = var.tags
}

module "config" {
  source = "../../modules/config"

  notification_topic_arn    = module.cloudwatch_alerts.sns_topic_arns["routine"]
  create_notification_topic = false
  create_recorder           = false  # Already configured

  tags = var.tags
}
```

Now Config compliance alerts and CloudWatch instance alarms all route to the same "routine" channel.

## AWS Limits

- **Config Recorder Limit**: Only **1 customer-managed recorder** per region. If you already have one, set `create_recorder = false`.
- **Config Rules**: Limited by AWS quotas (typically 100 rules per account). This module creates 1.

## Cost Considerations

- **AWS Config**: Charged per rule evaluation. For this periodic custom rule, estimate `EC2 instance count × evaluations per month × the current AWS Config per-evaluation rate` (about 720 evaluations per instance each month at the hourly default).
- **Lambda**: Charged per invocation and duration
- **S3**: Small storage cost for Config snapshots and Lambda artifacts
- **SNS**: Charged per notification sent

Total cost scales with the number of EC2 instances, evaluation frequency, configuration-item recording, and notification volume; use current AWS pricing for an account-specific estimate.
