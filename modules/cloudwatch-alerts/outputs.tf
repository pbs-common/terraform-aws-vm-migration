output "sns_topic_arns" {
  description = "Map of notification channel key to its SNS topic ARN. Point any additional alarm_actions/ok_actions at one of these to reuse that channel's subscriptions."
  value       = { for key, topic in aws_sns_topic.this : key => topic.arn }
}

output "webhook_forwarder_function_arns" {
  description = "Map of notification channel key to its webhook forwarder Lambda ARN, for channels that configured slack_webhook_secret_arn or teams_webhook_secret_arn."
  value       = { for key, fn in aws_lambda_function.webhook_forwarder : key => fn.arn }
}

output "alarm_arns" {
  description = "Map of alarm name to its CloudWatch alarm ARN."
  value       = { for name, alarm in aws_cloudwatch_metric_alarm.this : name => alarm.arn }
}
