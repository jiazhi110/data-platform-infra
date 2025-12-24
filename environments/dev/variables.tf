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
  # dev 环境中 MSK Broker 的实例类型。
  description = "The EC2 instance type for MSK broker nodes in development"
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka version for the cluster"
  type        = string
  default     = "3.8.x"
}

variable "flink_output_bucket" {
  description = "Name of the S3 bucket for Flink output and state"
  type        = string
}

variable "flink_task_cpu" {
  description = "CPU units for the Flink ECS task"
  type        = string
}

variable "flink_task_memory" {
  description = "Memory (MiB) for the Flink ECS task"
  type        = string
}

# ------------------------------------------------------------------------------
# Mock Data Generation Variables
# ------------------------------------------------------------------------------
variable "mock_data_image" {
  description = "Docker image URI for the mock data generator"
  type        = string
}

variable "mock_data_schedule" {
  description = "Schedule for the mock data task (Cron expression)"
  type        = string
  default     = null
}

variable "runner_security_group_name" {
  description = "Name of the security group for the self-hosted runner"
  type        = string
}

variable "runner_iam_role_name" {
  description = "Name of the IAM role for the EC2 runner instance"
  type        = string
}

# ------------------------------------------------------------------------------
# ETL Module Variables (Glue)
# ------------------------------------------------------------------------------
variable "glue_trigger_schedule" {
  description = "Schedule for the Glue ETL job (Cron expression)"
  type        = string
}

variable "crawler_schedule" {
  description = "Schedule for the Glue crawler (Cron expression)"
  type        = string
}

# ------------------------------------------------------------------------------
# Monitoring & Alerting
# ------------------------------------------------------------------------------
variable "alert_email" {
  description = "Email address for receiving system alerts"
  type        = string
}