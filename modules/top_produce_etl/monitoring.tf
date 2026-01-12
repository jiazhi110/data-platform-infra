# --- AWS Glue Monitoring ---
# Monitor AWS Glue Job state transitions.
resource "aws_cloudwatch_event_rule" "glue_failure" {
  name        = "${var.project_name}-${var.environment}-glue-failure-rule"
  description = "Capture each time a Glue Job fails."

  event_pattern = jsonencode({
    source      = ["aws.glue"],
    detail-type = ["Glue Job State Change"],
    detail = {
      jobName = [aws_glue_job.top_produce_etl_job.name],
      state   = ["FAILED", "TIMEOUT", "STOPPED"]
    }
  })
}

# SNS target for Glue job failure alerts.
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.glue_failure.name
  target_id = "SendToSNS"
  arn       = var.sns_alert_topic_arn

  input_transformer {
    input_paths = {
      jobName = "$.detail.jobName",
      state   = "$.detail.state",
      error   = "$.detail.message"
    }
    input_template = jsonencode("ALERT: Glue Job <jobName> has <state>. Error: <error>")
  }
}
