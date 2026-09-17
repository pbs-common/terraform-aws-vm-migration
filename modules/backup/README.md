# AWS Backup Module

This module creates and manages AWS Backup resources for automated backup and recovery of EC2 instances and other supported AWS resources.

## Features

- Creates an AWS Backup vault with encryption (AWS-managed by default, or customer-managed KMS key)
- Configurable backup plan with customizable schedule and retention
- Automatic resource selection based on tags
- IAM service role with necessary permissions

## Usage

Tag resources you want backed up with `backup-enable=true`, then reference this module:

```hcl
module "backup" {
  source = "./modules/backup"

  vault_name  = "my-backup-vault"
  kms_key_id  = aws_kms_key.backup.id

  backup_schedule      = "cron(0 1 * * ? *)"  # Daily at 1 AM UTC
  backup_retention_days = 30

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
| kms_key_id | KMS key ID/ARN for customer-managed encryption (AWS-managed encryption used if null) | `string` | `null` | no |
| backup_schedule | Backup schedule in cron format | `string` | `"cron(0 1 * * ? *)"` | no |
| backup_retention_days | Days to retain backups | `number` | `30` | no |
| backup_tag_key | Tag key to identify resources | `string` | `"backup-enable"` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| backup_vault_arn | ARN of the backup vault |
| backup_vault_id | ID of the backup vault |
| backup_vault_name | Name of the backup vault |
