# AWS Config monitoring: Recorder -> Delivery Channel -> Config Rule -> Lambda Evaluator -> SNS Alerts

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Check if a Config recorder already exists in this region
data "aws_config_configuration_recorders" "existing" {}

locals {
  recorder_exists = length(data.aws_config_configuration_recorders.existing.ids) > 0
}

# ---------------------------------------------------------------------------
# AWS Config Recorder & Delivery Channel (created only if none exist)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "config" {
  count  = local.recorder_exists ? 0 : 1
  bucket = "${var.config_bucket_name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
}

resource "aws_s3_bucket_versioning" "config" {
  count  = local.recorder_exists ? 0 : 1
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "config" {
  count  = local.recorder_exists ? 0 : 1
  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowConfigPutObject"
      Effect = "Allow"
      Principal = {
        Service = "config.amazonaws.com"
      }
      Action   = "s3:PutObject"
      Resource = "${aws_s3_bucket.config[0].arn}/*"
      Condition = {
        StringEquals = {
          "s3:x-amz-acl" = "bucket-owner-full-control"
        }
      }
    }]
  })
}

resource "aws_iam_role" "config_recorder" {
  count = local.recorder_exists ? 0 : 1
  name  = "${var.rule_name}-recorder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_recorder" {
  count      = local.recorder_exists ? 0 : 1
  role       = aws_iam_role.config_recorder[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

resource "aws_iam_role_policy" "config_recorder_s3" {
  count = local.recorder_exists ? 0 : 1
  name  = "${var.rule_name}-recorder-s3"
  role  = aws_iam_role.config_recorder[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetBucketVersioning",
        "s3:GetBucketAcl",
        "s3:PutObject",
        "s3:GetObject"
      ]
      Resource = [
        aws_s3_bucket.config[0].arn,
        "${aws_s3_bucket.config[0].arn}/*"
      ]
    }]
  })
}

resource "aws_config_configuration_recorder" "main" {
  count    = local.recorder_exists ? 0 : 1
  name     = "${var.rule_name}-recorder"
  role_arn = aws_iam_role.config_recorder[0].arn
  recording_group {
    all_supported = true
  }

  depends_on = [aws_iam_role_policy.config_recorder_s3]
}

resource "aws_config_delivery_channel" "main" {
  count          = local.recorder_exists ? 0 : 1
  name           = "${var.rule_name}-channel"
  s3_bucket_name = aws_s3_bucket.config[0].id

  snapshot_delivery_properties {
    delivery_frequency = var.config_snapshot_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = local.recorder_exists ? 0 : 1
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# ---------------------------------------------------------------------------
# Lambda that evaluates every instance
# ---------------------------------------------------------------------------

data "archive_file" "checker" {
  type        = "zip"
  source_file = "${path.module}/ec2_alarm_check.py"
  output_path = "${path.module}/ec2_alarm_check.zip"
}

resource "aws_iam_role" "checker" {
  name = "${var.rule_name}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "checker_logs" {
  role       = aws_iam_role.checker.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "checker" {
  name = "evaluate-ec2-alarms"
  role = aws_iam_role.checker.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "cloudwatch:DescribeAlarms",
        "config:PutEvaluations",
        "config:GetComplianceDetailsByConfigRule",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "checker" {
  function_name    = var.rule_name
  role             = aws_iam_role.checker.arn
  runtime          = "python3.12"
  handler          = "ec2_alarm_check.handler"
  filename         = data.archive_file.checker.output_path
  source_code_hash = data.archive_file.checker.output_base64sha256
  timeout          = 300

  environment {
    variables = {
      REQUIRED_METRICS      = jsonencode(var.required_metrics)
      REQUIRE_ALARM_ACTIONS = tostring(var.require_alarm_actions)
    }
  }
}

resource "aws_lambda_permission" "config" {
  statement_id   = "AllowConfigInvoke"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.checker.function_name
  principal      = "config.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------
# The Config rule
# ---------------------------------------------------------------------------

resource "aws_config_config_rule" "ec2_alarms" {
  name        = var.rule_name
  description = "Every EC2 instance must have CloudWatch alarms for CPU, memory and disk."

  source {
    owner             = "CUSTOM_LAMBDA"
    source_identifier = aws_lambda_function.checker.arn

    source_detail {
      message_type                = "ScheduledNotification"
      maximum_execution_frequency = var.evaluation_frequency
    }
  }

  depends_on = [
    aws_lambda_permission.config,
    aws_config_configuration_recorder_status.main,
  ]
}

# ---------------------------------------------------------------------------
# Alerting: Config compliance change -> EventBridge -> SNS
# ---------------------------------------------------------------------------

resource "aws_sns_topic" "alerts" {
  name = "${var.rule_name}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_policy" "alerts" {
  arn = aws_sns_topic.alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgePublish"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alerts.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "noncompliant" {
  name        = "${var.rule_name}-noncompliant"
  description = "An EC2 instance became non-compliant with ${var.rule_name}."

  event_pattern = jsonencode({
    source        = ["aws.config"]
    "detail-type" = ["Config Rules Compliance Change"]
    detail = {
      configRuleName      = [var.rule_name]
      newEvaluationResult = { complianceType = ["NON_COMPLIANT"] }
    }
  })
}

resource "aws_cloudwatch_event_target" "sns" {
  rule = aws_cloudwatch_event_rule.noncompliant.name
  arn  = aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      instance   = "$.detail.resourceId"
      account    = "$.detail.awsAccountId"
      region     = "$.detail.awsRegion"
      annotation = "$.detail.newEvaluationResult.annotation"
    }
    input_template = "\"EC2 instance <instance> (account <account>, <region>) is missing required CloudWatch alarms. <annotation>\""
  }
}
