# -----------------------------------------------------------------------------
# Ingestion Kafka/Flink Module - outputs.tf
#
# Output critical information created by this module.
# -----------------------------------------------------------------------------

output "kafka_bootstrap_brokers_plaintext" {
  description = "Plaintext connection string for the Kafka cluster."
  sensitive   = true
  value       = aws_msk_cluster.kafka_cluster.bootstrap_brokers
}

output "msk_bootstrap_brokers_sasl_iam" {
  description = "SASL/IAM connection string for the Kafka cluster."
  value       = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
}

output "ecs_tasks_sg_id" {
  description = "Security Group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks_sg.id
}

output "msk_cluster_arn" {
  description = "ARN of the created MSK cluster"
  value       = aws_msk_cluster.kafka_cluster.arn
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main_cluster.name
}

output "mock_data_task_family" {
  description = "The family of the mock data ECS task"
  value       = aws_ecs_task_definition.mock_data_task.family
}

output "flink_output_bucket" {
  description = "The name of the S3 bucket used for Flink output and scripts"
  value       = aws_s3_bucket.flink_output_bucket.bucket
}