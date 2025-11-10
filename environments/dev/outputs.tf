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