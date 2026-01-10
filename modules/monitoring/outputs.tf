output "sns_topic_arn" {
  # The ARN of the SNS alerting topic.
  # SNS 报警主题的 ARN。
  description = "The ARN of the SNS alerting topic"
  value       = aws_sns_topic.alerts.arn
}