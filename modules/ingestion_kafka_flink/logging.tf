# --- MSK Kafka cloudwatch ---
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.msk_cluster_name}"
  retention_in_days = 14
}

# ===================================================================
# S3 Bucket for MSK Broker Logs
# ===================================================================
resource "aws_s3_bucket" "msk_logs_bucket" {
  bucket = var.msk_logs_bucket

  # 添加一个随机后缀，确保桶名在全局唯一
  # 如果不加，当别人也用了这个名字时，你的 apply 可能会失败
  # bucket_prefix = "my-justin-data-platform-logs-" 
  # Conflicting configuration arguments
  # bucket_prefix = var.msk_logs_bucket_prefix

  tags = {
    Name = "${var.project_name}-msk-logs-bucket"
  }
}

# CloudWatch 日志组 - 更新名称以适配 Flink
resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.flink_task_family}"
  retention_in_days = 14
}
