# AWS Backup Module

This module creates and manages AWS Backup resources for automated backup and recovery of EC2 instances and other supported AWS resources.

## Features

- Creates an AWS Backup vault with encryption (AWS-managed by default, or customer-managed KMS key)
- Configurable daily and weekly backup plans with separate schedules and retention policies
- Automatic resource selection based on tags
- IAM service role with necessary permissions

## Backup Plans

The module deploys two backup plans:

- **Daily Plan**: Runs every day at midnight UTC, retains backups for 14 days. Target resources with `daily-backups=true` tag.
- **Weekly Plan**: Runs Saturday at midnight UTC, retains backups for 12 days. Target resources with `weekly-backups=true` tag.

## Usage

Tag resources with `daily-backups=true` and/or `weekly-backups=true`, then reference this module:

```hcl
module "backup" {
  source = "./modules/backup"

  vault_name  = "my-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  daily_schedule      = "cron(0 0 * * ? *)"   # Every day at midnight UTC
  daily_retention_days = 14

  weekly_schedule      = "cron(0 0 ? * SAT *)"   # Saturday at midnight UTC
  weekly_retention_days = 12

  tags = {
    Environment = "prod"
  }
}
```

Resources are selected automatically by checking for `daily-backups=true` (for daily plan) or `weekly-backups=true` (for weekly plan) tags.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vault_name | Name of the backup vault | `string` | N/A | yes |
| kms_key_arn | ARN of the KMS key for customer-managed encryption (AWS-managed encryption used if null) | `string` | `null` | no |
| daily_schedule | Backup schedule for daily backups in cron format | `string` | `"cron(0 0 * * ? *)"` | no |
| daily_retention_days | Days to retain daily backups | `number` | `14` | no |
| weekly_schedule | Backup schedule for weekly backups in cron format | `string` | `"cron(0 0 ? * SAT *)"` | no |
| weekly_retention_days | Days to retain weekly backups | `number` | `12` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| backup_vault_arn | ARN of the backup vault |
| backup_vault_id | ID of the backup vault |
| backup_vault_name | Name of the backup vault |
| daily_plan_id | ID of the daily backup plan |
| daily_plan_arn | ARN of the daily backup plan |
| weekly_plan_id | ID of the weekly backup plan |
| weekly_plan_arn | ARN of the weekly backup plan |
