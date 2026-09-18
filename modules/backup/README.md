# AWS Backup Module

This module creates and manages AWS Backup resources for automated backup and recovery of EC2 instances and other supported AWS resources.

## Features

- Creates an AWS Backup vault with encryption (AWS-managed by default, or customer-managed KMS key)
- Configurable incremental and full backup plans with separate schedules and retention policies
- Automatic resource selection based on tags
- IAM service role with necessary permissions

## Backup Plans

The module deploys two backup plans:

- **Incremental Plan**: Runs nightly at midnight UTC, retains backups for 14 days
- **Full Plan**: Runs Saturday at midnight UTC, retains backups for 12 days

Both plans target resources tagged with `backup-enable=true`.

## Usage

Tag resources you want backed up with `backup-enable=true`, then reference this module:

```hcl
module "backup" {
  source = "./modules/backup"

  vault_name  = "my-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  incremental_schedule      = "cron(0 0 * * ? *)"   # Daily at midnight UTC
  incremental_retention_days = 14

  full_schedule      = "cron(0 0 ? * SAT *)"   # Saturday at midnight UTC
  full_retention_days = 12

  tags = {
    Environment = "prod"
  }
}
```

Resources are selected automatically by checking for the `backup-enable=true` tag.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vault_name | Name of the backup vault | `string` | N/A | yes |
| kms_key_arn | ARN of the KMS key for customer-managed encryption (AWS-managed encryption used if null) | `string` | `null` | no |
| incremental_schedule | Backup schedule for incremental backups in cron format | `string` | `"cron(0 0 * * ? *)"` | no |
| incremental_retention_days | Days to retain incremental backups | `number` | `14` | no |
| full_schedule | Backup schedule for full backups in cron format | `string` | `"cron(0 0 ? * SAT *)"` | no |
| full_retention_days | Days to retain full backups | `number` | `12` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| backup_vault_arn | ARN of the backup vault |
| backup_vault_id | ID of the backup vault |
| backup_vault_name | Name of the backup vault |
| incremental_plan_id | ID of the incremental backup plan |
| incremental_plan_arn | ARN of the incremental backup plan |
| full_plan_id | ID of the full backup plan |
| full_plan_arn | ARN of the full backup plan |
