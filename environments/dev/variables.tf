# ------------------------------------------------------------------------------
# Global Variables
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "Target AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name identifier"
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Environment identifier (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod"
  }
}

# ------------------------------------------------------------------------------
# Ingestion Module Variables (Kafka & Flink)
# ------------------------------------------------------------------------------
variable "kafka_broker_instance_type" {
  description = "EC2 instance type for MSK broker nodes"
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka cluster version"
  type        = string
  default     = "3.8.x"
}

variable "flink_output_bucket" {
  description = "S3 bucket for Flink output, checkpoints, and savepoints"
  type        = string
}

variable "flink_task_cpu" {
  description = "CPU allocation for the Flink ECS task"
  type        = string
}

variable "flink_task_memory" {
  description = "Memory (MiB) allocation for the Flink ECS task"
  type        = string
}

# ------------------------------------------------------------------------------
# Mock Data Generation Variables
# ------------------------------------------------------------------------------
variable "mock_data_image" {
  description = "Docker image URI for the mock data generator"
  type        = string
  default     = "ubuntu:latest"
}

variable "mock_data_schedule" {
  description = "Cron schedule for mock data generation"
  type        = string
  default     = null
}

variable "runner_security_group_name" {
  description = "Security group name for the self-hosted GHA runner"
  type        = string
}

variable "runner_iam_role_name" {
  description = "IAM role name for the runner EC2 instance"
  type        = string
}

# ------------------------------------------------------------------------------
# ETL Module Variables (Glue)
# ------------------------------------------------------------------------------
variable "glue_trigger_schedule" {
  description = "Cron schedule for the Glue ETL workflow"
  type        = string
}

variable "crawler_schedule" {
  description = "Cron schedule for the Glue Crawler"
  type        = string
}

# ------------------------------------------------------------------------------
# Monitoring & Alerting
# ------------------------------------------------------------------------------
variable "alert_email" {
  description = "Target email address for system-wide alert notifications"
  type        = string
}
