locals {
  # A channel with topic_arn set reuses an existing topic; subscriptions on it are
  # managed by whoever owns that topic, not this module.
  managed_channels = {
    for key, channel in var.notification_channels : key => channel
    if channel.topic_arn == null
  }

  # Channels with a webhook get a Lambda, role, and log group.
  channels_with_webhook = {
    for key, channel in local.managed_channels : key => channel
    if channel.slack_webhook_secret_arn != null || channel.teams_webhook_secret_arn != null
  }

  email_subscriptions = merge([
    for channel_key, channel in local.managed_channels : {
      for email in channel.email_subscriptions : "${channel_key}-${email}" => {
        channel_key = channel_key
        endpoint    = email
      }
    }
  ]...)

  sms_subscriptions = merge([
    for channel_key, channel in local.managed_channels : {
      for phone in channel.sms_subscriptions : "${channel_key}-${phone}" => {
        channel_key = channel_key
        endpoint    = phone
      }
    }
  ]...)

  pagerduty_channels = {
    for key, channel in local.managed_channels : key => channel
    if channel.pagerduty_integration_key_secret_arn != null
  }

  # Externally-owned ARN if set, else the topic this module created.
  topic_arns = {
    for key, channel in var.notification_channels : key => (
      channel.topic_arn != null ? channel.topic_arn : aws_sns_topic.this[key].arn
    )
  }
}

data "aws_secretsmanager_secret_version" "pagerduty" {
  for_each = local.pagerduty_channels

  secret_id = each.value.pagerduty_integration_key_secret_arn
}

resource "aws_sns_topic" "this" {
  for_each = local.managed_channels

  name = "${var.name}-${each.key}-alerts"
  # alias/aws/sns blocks CloudWatch Alarms from publishing here, confirmed directly.
  # Leave unencrypted unless a customer-managed key grants that permission.
  kms_master_key_id = var.sns_kms_key_arn

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-alerts" })
}

resource "aws_sns_topic_subscription" "email" {
  for_each = local.email_subscriptions

  topic_arn = aws_sns_topic.this[each.value.channel_key].arn
  protocol  = "email"
  endpoint  = each.value.endpoint
}

resource "aws_sns_topic_subscription" "sms" {
  for_each = local.sms_subscriptions

  topic_arn = aws_sns_topic.this[each.value.channel_key].arn
  protocol  = "sms"
  endpoint  = each.value.endpoint
}

# PagerDuty auto-confirms the subscription and parses the alarm itself, no Lambda needed.
resource "aws_sns_topic_subscription" "pagerduty" {
  for_each = local.pagerduty_channels

  topic_arn              = aws_sns_topic.this[each.key].arn
  protocol               = "https"
  endpoint               = "https://events.pagerduty.com/integration/${data.aws_secretsmanager_secret_version.pagerduty[each.key].secret_string}/enqueue"
  endpoint_auto_confirms = true
}

# Slack and Teams webhooks don't support the SNS confirmation handshake and expect
# their own JSON shape, not the raw SNS envelope. Each channel with a webhook gets its
# own Lambda forwarder, subscribed to that channel's topic, to reshape and send it.
#
# Code comes from S3, zipped and uploaded by the null_resource below, during apply - not
# a local archive_file. Plan and apply run as separate CI jobs on separate runners, so a
# zip built during plan never exists when apply's fresh checkout runs. Doing the zip/
# upload inside apply itself avoids that, and avoids a separate CI job needing its own
# approval gate for ad/staging/prod on top of apply's. The key is content-addressed
# (source hash appended) so concurrent runs for different commits never overwrite each
# other's upload.
locals {
  webhook_forwarder_source_hash     = filebase64sha256("${path.module}/lambda/webhook_forwarder.py")
  webhook_forwarder_source_hash_hex = filesha256("${path.module}/lambda/webhook_forwarder.py")
  webhook_forwarder_s3_key          = "${var.lambda_artifact_s3_prefix}/webhook_forwarder-${local.webhook_forwarder_source_hash_hex}.zip"
}

resource "null_resource" "webhook_forwarder_upload" {
  # Only needed when some channel actually has a Lambda to upload.
  for_each = length(local.channels_with_webhook) > 0 ? { once = true } : {}

  # Re-runs only when the source changes, same as archive_file's old behavior.
  triggers = {
    source_hash = local.webhook_forwarder_source_hash_hex
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/lambda && zip -o webhook_forwarder.zip webhook_forwarder.py && aws s3 cp webhook_forwarder.zip s3://${var.lambda_artifact_s3_bucket}/${local.webhook_forwarder_s3_key}"
  }
}

resource "aws_iam_role" "webhook_forwarder" {
  for_each = local.channels_with_webhook

  name = "${var.name}-${each.key}-webhook-forwarder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-webhook-forwarder" })
}

resource "aws_iam_role_policy_attachment" "webhook_forwarder_logs" {
  for_each = local.channels_with_webhook

  role       = aws_iam_role.webhook_forwarder[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Scoped to this channel's own secret(s), never account-wide access.
resource "aws_iam_role_policy" "webhook_forwarder_secrets" {
  for_each = local.channels_with_webhook

  name = "${var.name}-${each.key}-webhook-forwarder-secrets"
  role = aws_iam_role.webhook_forwarder[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = compact([each.value.slack_webhook_secret_arn, each.value.teams_webhook_secret_arn])
    }]
  })
}

resource "aws_cloudwatch_log_group" "webhook_forwarder" {
  for_each = local.channels_with_webhook

  name              = "/aws/lambda/${var.name}-${each.key}-webhook-forwarder"
  retention_in_days = var.lambda_log_retention_days

  tags = var.tags
}

resource "aws_lambda_function" "webhook_forwarder" {
  for_each = local.channels_with_webhook

  function_name = "${var.name}-${each.key}-webhook-forwarder"
  role          = aws_iam_role.webhook_forwarder[each.key].arn
  handler       = "webhook_forwarder.handler"
  runtime       = "python3.13"
  # Slack and Teams post sequentially, 5s each - 10s leaves no room for secrets
  # fetch, cold start, or a multi-record batch.
  timeout          = 30
  s3_bucket        = var.lambda_artifact_s3_bucket
  s3_key           = local.webhook_forwarder_s3_key
  source_code_hash = local.webhook_forwarder_source_hash

  environment {
    # coalesce() errors here instead of returning "" when both are null, which is
    # what happens whenever a channel sets only one of the two webhooks.
    variables = {
      SLACK_WEBHOOK_SECRET_ARN = each.value.slack_webhook_secret_arn != null ? each.value.slack_webhook_secret_arn : ""
      TEAMS_WEBHOOK_SECRET_ARN = each.value.teams_webhook_secret_arn != null ? each.value.teams_webhook_secret_arn : ""
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.webhook_forwarder,
    aws_iam_role_policy_attachment.webhook_forwarder_logs,
    aws_iam_role_policy.webhook_forwarder_secrets,
    null_resource.webhook_forwarder_upload,
  ]

  tags = merge(var.tags, { Name = "${var.name}-${each.key}-webhook-forwarder" })
}

resource "aws_lambda_permission" "webhook_forwarder_sns" {
  for_each = local.channels_with_webhook

  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_forwarder[each.key].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.this[each.key].arn
}

resource "aws_sns_topic_subscription" "webhook_forwarder" {
  for_each = local.channels_with_webhook

  topic_arn = aws_sns_topic.this[each.key].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.webhook_forwarder[each.key].arn
}
