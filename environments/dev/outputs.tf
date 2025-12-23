output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = module.ingestion.ecs_cluster_name
}

output "mock_data_task_family" {
  description = "The family of the mock data ECS task."
  value       = module.ingestion.mock_data_task_family
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = data.terraform_remote_state.network.outputs.private_subnet_ids
}

output "ecs_tasks_sg_id" {
  description = "ecs task 的 sg id"
  value       = module.ingestion.ecs_tasks_sg_id
}

output "msk_bootstrap_brokers" {
  description = "MSK SASL/IAM Connection String"
  value       = module.ingestion.msk_bootstrap_brokers_sasl_iam
}

output "flink_output_bucket" {
  description = "S3 Data Lake Bucket"
  value       = module.ingestion.flink_output_bucket
}

output "glue_job_name" {
  description = "ETL Glue Job Name"
  value       = module.top_produce_etl.glue_job_name
}

output "athena_database" {
  description = "Athena/Glue Catalog Database"
  value       = module.top_produce_etl.athena_database_name
}
