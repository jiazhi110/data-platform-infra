output "ecs_cluster_name" {
  # The name of the ECS cluster.
  # ECS 集群的名称。
  description = "The name of the ECS cluster."
  value       = module.ingestion.ecs_cluster_name
}

output "mock_data_task_family" {
  # The family of the mock data ECS task.
  # Mock 数据 ECS 任务的任务族名称。
  description = "The family of the mock data ECS task."
  value       = module.ingestion.mock_data_task_family
}

output "private_subnet_ids" {
  # List of private subnet IDs from the network layer.
  # 来自网络层的私有子网 ID 列表。
  description = "List of private subnet IDs"
  value       = data.terraform_remote_state.network.outputs.private_subnet_ids
}

output "ecs_tasks_sg_id" {
  # Security Group ID for ECS tasks.
  # ECS 任务的安全组 ID。
  description = "ecs task 的 sg id"
  value       = module.ingestion.ecs_tasks_sg_id
}

output "msk_bootstrap_brokers" {
  # SASL/IAM connection string for the MSK cluster.
  # MSK 集群的 SASL/IAM 连接字符串。
  description = "MSK SASL/IAM Connection String"
  value       = module.ingestion.msk_bootstrap_brokers_sasl_iam
}

output "flink_output_bucket" {
  # S3 bucket name acting as the data lake.
  # 用作数据湖的 S3 桶名称。
  description = "S3 Data Lake Bucket"
  value       = module.ingestion.flink_output_bucket
}

output "glue_job_name" {
  # The name of the ETL Glue job.
  # ETL Glue 任务的名称。
  description = "ETL Glue Job Name"
  value       = module.top_produce_etl.glue_job_name
}

output "athena_database" {
  # The database name in Glue Data Catalog for Athena querying.
  # Athena 在 Glue 数据目录中的数据库名称。
  description = "Athena/Glue Catalog Database"
  value       = module.top_produce_etl.athena_database_name
}
