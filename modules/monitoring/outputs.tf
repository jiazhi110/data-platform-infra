output "sns_topic_arn" {
  description = "The ARN of the SNS alerting topic"
  value       = aws_sns_topic.alerts.arn
}
