output "sns_topic_arns" {
  description = "Map of notification channel key to its SNS topic ARN. Point alarm_actions/ok_actions at one of these to notify through that channel."
  value       = local.topic_arns
}

output "webhook_forwarder_function_arns" {
  description = "Map of notification channel key to its webhook forwarder Lambda ARN, for channels that configured slack_webhook_secret_arn or teams_webhook_secret_arn."
  value       = { for key, fn in aws_lambda_function.webhook_forwarder : key => fn.arn }
}
