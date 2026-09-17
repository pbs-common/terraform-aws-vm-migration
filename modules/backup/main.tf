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
  force_destroy   = false

  tags = merge(
    var.tags,
    {
      Name = var.vault_name
    }
  )
}

resource "aws_backup_plan" "this" {
  name = "${var.vault_name}-backup-plan"

  rule {
    rule_name         = "${var.vault_name}-backup-rule"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.backup_schedule

    lifecycle {
      delete_after = var.backup_retention_days
    }
  }
}

# Create backup selection for resources tagged with backup-enable=true
resource "aws_backup_selection" "tag_based_true" {
  name         = "${var.vault_name}-tag-true"
  plan_id      = aws_backup_plan.this.id
  iam_role_arn = aws_iam_role.backup_service_role.arn

  selection_tag {
    type   = "STRINGEQUALS"
    key    = "backup-enable"
    value  = "true"
  }
}

