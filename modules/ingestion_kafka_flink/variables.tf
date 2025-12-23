# Ingestion Kafka Flink Module Variables

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

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
}

variable "runner_security_group_name" {
  description = "The name of the security group used by the self-hosted runner EC2 instance."
  type        = string
}

# --- Networking ---
variable "vpc_id" {
  description = "服务需要部署在哪个 VPC 中。"
  type        = string
}

variable "private_subnet_ids" {
  description = "MSK Kafka 集群需要使用的私有子网 ID 列表。"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the VPC, used for public-facing resources like ALBs."
  type        = list(string)
}

# --- MSK Kafka ---
variable "kafka_broker_instance_type" {
  description = "MSK Broker 节点的 EC2 实例类型。"
  type        = string
  default     = "kafka.t3.small"
}

variable "kafka_version" {
  description = "Apache Kafka 的版本。"
  type        = string
}

# --- Flink ---
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

variable "flink_image_url" {
  description = "The URL of the Flink image."
  type        = string
}

# --- Mock Data ---
variable "mockdata_image_url" {
  description = "The URL of the mock data image."
  type        = string
}

variable "mock_data_schedule" {
  description = "Cron expression for the mock data generation schedule. If null, the rule is disabled."
  type        = string
  default     = null
}

variable "runner_iam_role_name" {
  description = "The name of the IAM role attached to the EC2 runner instance for manual Kafka consumption."
  type        = string
}

# --- Alerting ---
variable "sns_alert_topic_arn" {
  description = "The ARN of the SNS topic to send alerts to."
  type        = string
}
