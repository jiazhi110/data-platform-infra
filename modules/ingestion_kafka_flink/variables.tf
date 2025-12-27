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
  # 服务需要部署在哪个 VPC 中。
  description = "The VPC ID where resources will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  # MSK Kafka 集群需要使用的私有子网 ID 列表。
  description = "List of private subnet IDs for the MSK cluster"
  type        = list(string)
}

variable "public_subnet_ids" {
  # 用于公网资源（如 ALB）的公共子网 ID 列表。
  description = "List of public subnet IDs for the VPC"
  type        = list(string)
}

# --- MSK Kafka ---
variable "kafka_broker_instance_type" {
  # MSK Broker 节点的 EC2 实例类型。
  description = "The instance type for MSK broker nodes"
  type        = string
  default     = "kafka.t3.small"
}

variable "kafka_version" {
  # Apache Kafka 的版本。
  description = "The version of Apache Kafka for the MSK cluster"
  type        = string
}

# --- Flink ---
variable "flink_output_bucket" {
  # Flink 任务的输出 S3 桶，用于存储处理后的数据、Checkpoints 和 Savepoints。
  description = "The S3 bucket for Flink output data and state"
  type        = string
}

variable "flink_task_cpu" {
  # Flink ECS 任务使用的 CPU 单元。
  description = "CPU units for the Flink ECS task"
  type        = string
}

variable "flink_task_memory" {
  # Flink ECS 任务使用的内存 (MiB)。
  description = "Memory (MiB) for the Flink ECS task"
  type        = string
}

variable "flink_image_url" {
  # Flink Docker 镜像的 ECR URL。
  description = "The URL of the Flink Docker image"
  type        = string
}

# --- Mock Data ---
variable "mockdata_image_url" {
  # Mock 数据生成器的 Docker 镜像 URL。
  description = "The URL of the mock data generator Docker image"
  type        = string
}

variable "mock_data_schedule" {
  # Mock 数据生成的定时表达式 (Cron)。
  description = "Cron expression for the mock data generation schedule"
  type        = string
  default     = null
}

variable "runner_iam_role_name" {
  # 附加到 EC2 runner 实例用于手动 Kafka 消费的 IAM 角色名称。
  description = "The IAM role name for the EC2 runner instance"
  type        = string
}

# --- Alerting ---
variable "sns_alert_topic_arn" {
  # 用于发送系统报警的 SNS Topic ARN。
  description = "The ARN of the SNS topic to send alerts to"
  type        = string
}
