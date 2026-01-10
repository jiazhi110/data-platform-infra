# -----------------------------------------------------------------------------
# Ingestion Kafka/Flink Module - outputs.tf
#
# Output critical information created by this module, especially Kafka connection addresses.
# 输出这个模块创建的关键信息，特别是 Kafka 的连接地址。
# -----------------------------------------------------------------------------

output "kafka_bootstrap_brokers_plaintext" {
  # Plaintext connection string for the Kafka cluster.
  # Kafka 集群的 Plaintext 连接地址。
  description = "Plaintext connection string for the Kafka cluster."
  # Set sensitive to true so this value is not displayed directly in apply output.
  # 将 sensitive 设置为 true，这样 apply 的结果中不会直接显示这个值。
  sensitive = true
  value     = aws_msk_cluster.kafka_cluster.bootstrap_brokers
}

output "msk_bootstrap_brokers_sasl_iam" {
  # SASL/IAM connection string for the Kafka cluster (Recommended for Prod/Dev).
  # Kafka 集群的 SASL/IAM 连接地址 (生产/开发推荐)。
  description = "SASL/IAM connection string for the Kafka cluster (Recommended for Prod/Dev)."
  value       = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
}

output "ecs_tasks_sg_id" {
  # Security Group ID for ECS tasks.
  # ecs task 的 sg id
  description = "Security Group ID for ECS tasks"
  value = aws_security_group.ecs_tasks_sg.id
}

output "msk_cluster_arn" {
  # ARN of the created MSK cluster.
  # 创建的 MSK 集群的 ARN。
  description = "ARN of the created MSK cluster"
  value       = aws_msk_cluster.kafka_cluster.arn
}

output "ecs_cluster_name" {
  # The name of the ECS cluster.
  # ECS 集群的名称。
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main_cluster.name
}

output "mock_data_task_family" {
  # The family of the mock data ECS task.
  # Mock 数据 ECS 任务的任务族名称。
  description = "The family of the mock data ECS task"
  value       = aws_ecs_task_definition.mock_data_task.family
}

output "flink_output_bucket" {
  # The name of the S3 bucket used for Flink output and scripts.
  # 用于 Flink 输出和脚本的 S3 桶名称。
  description = "The name of the S3 bucket used for Flink output and scripts"
  value       = aws_s3_bucket.flink_output_bucket.bucket
}
