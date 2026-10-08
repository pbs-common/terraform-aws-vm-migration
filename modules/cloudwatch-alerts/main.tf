locals {
  # Channels with a webhook get a Lambda, role, and log group.
  channels_with_webhook = {
    for key, channel in var.notification_channels : key => channel
    if channel.slack_webhook_secret_arn != null || channel.teams_webhook_secret_arn != null
  }

  email_subscriptions = merge([
    for channel_key, channel in var.notification_channels : {
      for email in channel.email_subscriptions : "${channel_key}-${email}" => {
        channel_key = channel_key
        endpoint    = email
      }
    }
  ]...)

  sms_subscriptions = merge([
    for channel_key, channel in var.notification_channels : {
      for phone in channel.sms_subscriptions : "${channel_key}-${phone}" => {
        channel_key = channel_key
        endpoint    = phone
      }
    }
  ]...)

  pagerduty_channels = {
    for key, channel in var.notification_channels : key => channel
    if channel.pagerduty_integration_key_secret_arn != null
  }

  alarms_by_name = { for a in var.alarms : a.name => a }
}

data "aws_secretsmanager_secret_version" "pagerduty" {
  for_each = local.pagerduty_channels

  secret_id = each.value.pagerduty_integration_key_secret_arn
}

resource "aws_sns_topic" "this" {
  for_each = var.notification_channels

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
data "archive_file" "webhook_forwarder" {
  type        = "zip"
  source_file = "${path.module}/lambda/webhook_forwarder.py"
  output_path = "${path.module}/.build/webhook_forwarder.zip"
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
  filename         = data.archive_file.webhook_forwarder.output_path
  source_code_hash = data.archive_file.webhook_forwarder.output_base64sha256

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

# CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarms_by_name

  alarm_name          = "${var.name}-${each.value.name}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  statistic           = each.value.statistic
  period              = each.value.period
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  dimensions          = each.value.dimensions
  treat_missing_data  = each.value.treat_missing_data
  actions_enabled     = var.actions_enabled

  alarm_actions = [aws_sns_topic.this[each.value.notification_channel].arn]
  ok_actions    = each.value.notify_ok ? [aws_sns_topic.this[each.value.notification_channel].arn] : []

  tags = merge(var.tags, { Name = "${var.name}-${each.value.name}" })
}
