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

# Attach restore policy if needed
resource "aws_iam_role_policy_attachment" "backup_restore_policy" {
  role       = aws_iam_role.backup_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_vault" "this" {
  name        = var.vault_name
  kms_key_arn = var.kms_key_arn
  force_destroy = false

  tags = merge(
    var.tags,
    {
      Name = var.vault_name
    }
  )
}

resource "aws_backup_plan" "incremental" {
  name = "${var.vault_name}-incremental-plan"

  rule {
    rule_name         = "${var.vault_name}-incremental-rule"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.incremental_schedule

    lifecycle {
      delete_after = var.incremental_retention_days
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "disabled"
    }
    resource_type = "EC2"
  }
}

resource "aws_backup_plan" "full" {
  name = "${var.vault_name}-full-plan"

  rule {
    rule_name         = "${var.vault_name}-full-rule"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.full_schedule

    lifecycle {
      delete_after = var.full_retention_days
    }
  }

  advanced_backup_setting {
    backup_options = {
      WindowsVSS = "disabled"
    }
    resource_type = "EC2"
  }
}

# Create backup selections for incremental plan
resource "aws_backup_selection" "incremental" {
  name         = "${var.vault_name}-incremental-selection"
  plan_id      = aws_backup_plan.incremental.id
  iam_role_arn = aws_iam_role.backup_service_role.arn

  depends_on = [aws_iam_role_policy_attachment.backup_service_policy]

  selection_tag {
    type   = "STRINGEQUALS"
    key    = "backup-enable"
    value  = "true"
  }
}

# Create backup selections for full plan
resource "aws_backup_selection" "full" {
  name         = "${var.vault_name}-full-selection"
  plan_id      = aws_backup_plan.full.id
  iam_role_arn = aws_iam_role.backup_service_role.arn

  depends_on = [aws_iam_role_policy_attachment.backup_service_policy]

  selection_tag {
    type   = "STRINGEQUALS"
    key    = "backup-enable"
    value  = "true"
  }
}

