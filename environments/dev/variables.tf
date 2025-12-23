# ------------------------------------------------------------------------------
# Global Variables
# ------------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Environment name (dev, prod)"
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
  description = "dev 环境中 MSK Broker 的实例类型。"
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka 的版本。"
  type        = string
  default     = "3.8.x"
}

variable "flink_output_bucket" {
  description = "ingestion-flink-output-s3"
  type        = string
}

variable "flink_task_cpu" {
  description = "flink_task_cpu"
  type        = string
}

variable "flink_task_memory" {
  description = "flink_task_memory"
  type        = string
}

# ------------------------------------------------------------------------------
# Mock Data Generation Variables
# ------------------------------------------------------------------------------
variable "mock_data_image" {
  description = "Docker image for the mock data generator task."
  type        = string
  default     = "ubuntu:latest" # Placeholder
}

variable "mock_data_schedule" {
  description = "The schedule for the mock data generator."
  type        = string
  default     = null
}

variable "runner_security_group_name" {
  description = "The name of the security group for the self-hosted runner."
  type        = string
}

variable "runner_iam_role_name" {
  description = "The name of the IAM role for the EC2 runner instance."
  type        = string
}

# ------------------------------------------------------------------------------
# ETL Module Variables (Glue)
# ------------------------------------------------------------------------------
variable "glue_trigger_schedule" {
  description = "The cron schedule for the Glue job trigger."
  type        = string
}

variable "crawler_schedule" {
  description = "The cron schedule for the Glue crawler."
  type        = string
}

# ------------------------------------------------------------------------------
# Monitoring & Alerting
# ------------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address for receiving alerts"
  type        = string
}
