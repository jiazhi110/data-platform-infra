output "mock_data_schedule_rule_name" {
  description = "The name of the EventBridge rule for the mock data task."
  value       = module.ingestion.mock_data_schedule_rule_name
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = module.ingestion.ecs_cluster_name
}

output "mock_data_task_family" {
  description = "The family of the mock data ECS task."
  value       = module.ingestion.mock_data_task_family
}
