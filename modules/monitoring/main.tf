# SNS Topic for system-wide alerts.
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts-topic"
}

# Email subscription for alert notifications.
# Note: Manual confirmation is required via email after the first deployment.
resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
