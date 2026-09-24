# IAM role for AWS Backup service
resource "aws_iam_role" "backup_service_role" {
  name = "${var.vault_name}-backup-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.vault_name}-backup-service-role"
    }
  )
}

# Attach the AWS managed policy for backup service
resource "aws_iam_role_policy_attachment" "backup_service_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

# Additional policy required for backing up S3
resource "aws_iam_role_policy_attachment" "backup_s3_backup_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForS3Backup"
}

# Attach restore policy if needed
resource "aws_iam_role_policy_attachment" "backup_restore_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "this" {
  name          = var.vault_name
  kms_key_arn   = var.kms_key_arn
  force_destroy = false

  tags = merge(
    var.tags,
    {
      Name = var.vault_name
    }
  )
}

resource "aws_backup_plan" "daily" {
  name = "${var.vault_name}-daily-plan"

  rule {
    rule_name         = "${var.vault_name}-daily-rule"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.daily_schedule

    lifecycle {
      delete_after = var.daily_retention
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = var.windows_vss
    }
    resource_type = "EC2"
  }
}

# Create backup selections for daily plan
resource "aws_backup_selection" "daily" {
  name         = "${var.vault_name}-daily-selection"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup_service_role.arn

  depends_on = [aws_iam_role_policy_attachment.backup_service_policy]

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "daily_backups"
    value = "true"
  }
}

resource "aws_backup_plan" "weekly" {
  name = "${var.vault_name}-weekly-plan"

  rule {
    rule_name         = "${var.vault_name}-weekly-rule"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.weekly_schedule

    lifecycle {
      delete_after = var.weekly_retention
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = var.windows_vss
    }
    resource_type = "EC2"
  }
}

# Create backup selections for weekly plan
resource "aws_backup_selection" "weekly" {
  name         = "${var.vault_name}-weekly-selection"
  plan_id      = aws_backup_plan.weekly.id
  iam_role_arn = aws_iam_role.backup_service_role.arn

  depends_on = [aws_iam_role_policy_attachment.backup_service_policy]

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "weekly_backups"
    value = "true"
  }
}

