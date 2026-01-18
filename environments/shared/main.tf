# ------------------------------------------------------------------------------
# Shared Services Layer - Persistent Infrastructure
# ------------------------------------------------------------------------------

# --- ECR: Flink Producer ---
# Inherits tags (Project, Environment, Layer) from provider default_tags
resource "aws_ecr_repository" "producer_repo" {
  name                 = "${var.project_name}-flink-producer-repo"
  image_tag_mutability = "MUTABLE"
  # It automatically scans for security vulnerabilities.
  image_scanning_configuration {
    scan_on_push = true
  }
}

# SSM: Expose Flink Repo Name for CI/CD
resource "aws_ssm_parameter" "producer_repo_name" {
  name  = "/${var.project_name}/${var.environment}/ecr/producer_repo_name"
  type  = "String"
  value = aws_ecr_repository.producer_repo.name
}

# SSM: Persistent Pointer for Flink Image URL (Dev)
# Stores the specific image tag currently active for Dev.
resource "aws_ssm_parameter" "flink_image_url_dev" {
  name  = "/${var.project_name}/dev/ingestion/flink_job_image_url"
  type  = "String"
  value = "PLACEHOLDER_UPDATED_BY_CI_CD"

  lifecycle {
    ignore_changes = [value]
  }

  # Override Environment tag because this specific resource serves the Dev environment
  tags = {
    Environment = "dev"
    Description = "Pointer to current Dev Flink Image"
  }
}

# --- ECR: Mock Data Generator ---
resource "aws_ecr_repository" "mock_data_repo" {
  name                 = "${var.project_name}-mock-data-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# SSM: Expose Mock Data Repo Name for CI/CD
resource "aws_ssm_parameter" "mock_data_repo_name" {
  name  = "/${var.project_name}/${var.environment}/ecr/mock_data_repo_name"
  type  = "String"
  value = aws_ecr_repository.mock_data_repo.name
}

# SSM: Persistent Pointer for Mock Data Image URL (Dev)
resource "aws_ssm_parameter" "mockdata_image_url_dev" {
  name  = "/${var.project_name}/dev/ingestion/mockdata_producer_image_url"
  type  = "String"
  value = "PLACEHOLDER_UPDATED_BY_CI_CD"

  lifecycle {
    ignore_changes = [value]
  }

  # Override Environment tag
  tags = {
    Environment = "dev"
    Description = "Pointer to current Dev Mock Data Image"
  }
}