# -----------------------------------------------------------------------------
# Ingestion Kafka/Flink Module - outputs.tf
#
# 输出这个模块创建的关键信息，特别是 Kafka 的连接地址。
# -----------------------------------------------------------------------------

output "kafka_bootstrap_brokers_plaintext" {
  description = "Kafka 集群的 Plaintext 连接地址。"
  # 将 sensitive 设置为 true，这样 apply 的结果中不会直接显示这个值。
  sensitive = true
  value     = aws_msk_cluster.kafka_cluster.bootstrap_brokers
}

output "ecs_tasks_sg_id" {
  description = "ecs task 的 sg id"
  value = aws_security_group.ecs_tasks_sg.id
}

output "msk_cluster_arn" {
  description = "创建的 MSK 集群的 ARN。"
  value       = aws_msk_cluster.kafka_cluster.arn
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main_cluster.name
}

output "mock_data_task_family" {
  description = "The family of the mock data ECS task."
  value       = aws_ecs_task_definition.mock_data_task.family
}

