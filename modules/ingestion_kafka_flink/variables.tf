# Ingestion Kafka Flink Module Variables

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-platform"
}

variable "environment" {
  description = "Deployment environment (dev, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod"
  }
}

variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
}

variable "runner_security_group_name" {
  description = "Security group name for the self-hosted runner"
  type        = string
}

# --- Networking ---
variable "vpc_id" {
  description = "Target VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the MSK cluster"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for internet-facing resources"
  type        = list(string)
}

# --- MSK Kafka ---
variable "kafka_broker_instance_type" {
  description = "MSK broker instance type"
  type        = string
  default     = "kafka.t3.small"
}

variable "kafka_version" {
  description = "Apache Kafka version"
  type        = string
}

# --- Flink ---
variable "flink_output_bucket" {
  description = "S3 bucket for Flink output and state"
  type        = string
}

variable "flink_task_cpu" {
  description = "CPU units for the Flink task"
  type        = string
}

variable "flink_task_memory" {
  description = "Memory (MiB) for the Flink task"
  type        = string
}

variable "flink_image_url" {
  description = "ECR URL for the Flink image"
  type        = string
}

# --- Mock Data ---
variable "mockdata_image_url" {
  description = "ECR URL for the mock data generator"
  type        = string
}

variable "mock_data_schedule" {
  description = "Cron expression for mock data generation"
  type        = string
  default     = null
}

variable "runner_iam_role_name" {
  description = "IAM role for the runner instance"
  type        = string
}

# --- Alerting ---
variable "sns_alert_topic_arn" {
  description = "SNS topic ARN for alerts"
  type        = string
}
