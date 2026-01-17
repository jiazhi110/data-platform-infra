output "producer_repo_url" {
  description = "URL of the Flink Producer ECR Repository"
  value       = aws_ecr_repository.producer_repo.repository_url
}

output "mock_data_repo_url" {
  description = "URL of the Mock Data Generator ECR Repository"
  value       = aws_ecr_repository.mock_data_repo.repository_url
}

# --- SSM Parameter Names (Pointers) ---
# Use these names in environment layers to lookup the current image URL.

output "flink_image_url_ssm_name" {
  description = "SSM Parameter Name for the Flink Image URL"
  value       = aws_ssm_parameter.flink_image_url_dev.name
}

output "mockdata_image_url_ssm_name" {
  description = "SSM Parameter Name for the Mock Data Image URL"
  value       = aws_ssm_parameter.mockdata_image_url_dev.name
}