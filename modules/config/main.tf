# AWS Config monitoring: Recorder -> Delivery Channel -> Config Rule -> Lambda Evaluator -> SNS Alerts

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # Use provided bucket or create one
  lambda_artifact_bucket = var.lambda_artifact_s3_bucket != null ? var.lambda_artifact_s3_bucket : aws_s3_bucket.lambda_artifacts[0].id
  
  checker_source_hash     = filebase64sha256("${path.module}/ec2_alarm_check.py")
  checker_source_hash_hex = filesha256("${path.module}/ec2_alarm_check.py")
  checker_s3_key          = "${var.lambda_artifact_s3_prefix}/ec2_alarm_check-${local.checker_source_hash_hex}.zip"
}

# Create S3 bucket for Lambda artifacts if not provided
resource "aws_s3_bucket" "lambda_artifacts" {
  count  = var.lambda_artifact_s3_bucket == null ? 1 : 0
  bucket = "${var.rule_name}-lambda-artifacts-${data.aws_caller_identity.current.account_id}"
  tags   = merge(var.tags, { Name = "${var.rule_name}-lambda-artifacts" })
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  count  = var.lambda_artifact_s3_bucket == null ? 1 : 0
  bucket = aws_s3_bucket.lambda_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------------------------------------------------------------------------
# AWS Config Recorder & Delivery Channel (created only if create_recorder = true)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "config" {
  count  = var.create_recorder ? 1 : 0
  bucket = "${var.config_bucket_name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  tags   = merge(var.tags, { Name = "${var.rule_name}-config" })
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.create_recorder ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "config" {
  count  = var.create_recorder ? 1 : 0
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
          "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          "s3:x-amz-acl"      = "bucket-owner-full-control"
        }
      }
    }]
  })
}

resource "aws_iam_role" "config_recorder" {
  count = var.create_recorder ? 1 : 0
  name  = "${var.rule_name}-recorder"
  tags  = merge(var.tags, { Name = "${var.rule_name}-recorder" })

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
  count      = var.create_recorder ? 1 : 0
  role       = aws_iam_role.config_recorder[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_recorder_s3" {
  count = var.create_recorder ? 1 : 0
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
  count      = var.create_recorder ? 1 : 0
  name     = "${var.rule_name}-recorder"
  role_arn = aws_iam_role.config_recorder[0].arn
  recording_group {
    all_supported = true
  }

  depends_on = [aws_iam_role_policy.config_recorder_s3]
}

resource "aws_config_delivery_channel" "main" {
  count          = var.create_recorder ? 1 : 0
  name           = "${var.rule_name}-channel"
  s3_bucket_name = aws_s3_bucket.config[0].id

  snapshot_delivery_properties {
    delivery_frequency = var.config_snapshot_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  count      = var.create_recorder ? 1 : 0
  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# ---------------------------------------------------------------------------
# Lambda that evaluates every instance
# ---------------------------------------------------------------------------

resource "null_resource" "checker_upload" {
  triggers = {
    s3_bucket = local.lambda_artifact_bucket
    s3_key    = local.checker_s3_key
  }

  provisioner "local-exec" {
    environment = {
      S3_BUCKET = local.lambda_artifact_bucket
      S3_KEY    = local.checker_s3_key
    }
    command = "cd ${path.module} && zip -o ec2_alarm_check.zip ec2_alarm_check.py && aws s3 cp ec2_alarm_check.zip \"s3://$S3_BUCKET/$S3_KEY\""
  }
}

resource "aws_iam_role" "checker" {
  name = "${var.rule_name}-lambda"
  tags = merge(var.tags, { Name = "${var.rule_name}-lambda" })

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
  runtime          = "python3.14"
  handler          = "ec2_alarm_check.handler"
  s3_bucket        = local.lambda_artifact_bucket
  s3_key           = local.checker_s3_key
  source_code_hash = local.checker_source_hash
  timeout          = 300
  tags             = merge(var.tags, { Name = var.rule_name })

  environment {
    variables = {
      REQUIRED_METRICS      = jsonencode(var.required_metrics)
      REQUIRE_ALARM_ACTIONS = tostring(var.require_alarm_actions)
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.checker_logs,
    aws_iam_role_policy.checker,
    null_resource.checker_upload,
  ]
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
  tags        = merge(var.tags, { Name = var.rule_name })

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

# Create a dedicated topic and subscribe email to it when requested.
resource "aws_sns_topic" "alerts" {
  count = var.create_notification_topic ? 1 : 0
  name  = "${var.rule_name}-alerts"
  tags  = merge(var.tags, { Name = "${var.rule_name}-alerts" })
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.create_notification_topic && var.alert_email != null ? 1 : 0
  topic_arn = aws_sns_topic.alerts[0].arn
  protocol  = "email"
  endpoint  = var.alert_email
}

locals {
  # Use the created topic when requested, otherwise use the provided topic
  notification_topic_arn = var.create_notification_topic ? aws_sns_topic.alerts[0].arn : var.notification_topic_arn
}

resource "aws_sns_topic_policy" "alerts" {
  count = var.create_notification_topic ? 1 : 0
  arn   = aws_sns_topic.alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowEventBridgePublish"
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alerts[0].arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.noncompliant.arn
        }
      }
    }]
  })
}

resource "aws_cloudwatch_event_rule" "noncompliant" {
  name        = "${var.rule_name}-noncompliant"
  description = "An EC2 instance became non-compliant with ${var.rule_name}."
  tags        = merge(var.tags, { Name = "${var.rule_name}-noncompliant" })

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
  arn  = local.notification_topic_arn

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
