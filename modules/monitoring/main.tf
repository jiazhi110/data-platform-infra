# Create SNS Topic for system alerts.
# 创建用于系统报警的 SNS 主题。
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts-topic"
}

# Create Email Subscription for the SNS Topic.
# Note: You must confirm the subscription via email after apply.
# 为 SNS 主题创建邮件订阅。
# 注意：Apply 之后，你必须在邮箱中确认订阅。
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}