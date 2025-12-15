# 监听 ECS Task 的状态变化
resource "aws_cloudwatch_event_rule" "flink_task_stop" {
  name        = "${var.project_name}-${var.environment}-flink-stop-rule"
  description = "Capture if the Flink ECS task stops unexpectedly."

  event_pattern = jsonencode({
    source      = ["aws.ecs"],
    detail-type = ["ECS Task State Change"],
    detail = {
      clusterArn = [aws_ecs_cluster.main_cluster.arn],
      lastStatus = ["STOPPED"],
      group      = ["service:${aws_ecs_service.producer_service.name}"]
    }
  })
}

# 触发目标：发送到 SNS
resource "aws_cloudwatch_event_target" "flink_sns_target" {
  rule      = aws_cloudwatch_event_rule.flink_task_stop.name
  target_id = "SendToSNS"
  arn       = var.sns_alert_topic_arn

  input_transformer {
    input_paths = {
      taskArn       = "$.detail.taskArn",
      stoppedReason = "$.detail.stoppedReason"
    }
    input_template = "CRITICAL: Flink Task <taskArn> has STOPPED. Reason: <stoppedReason>"
  }
}
