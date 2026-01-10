# ------------------------------------------------------------------------------
# Global Variables
# ------------------------------------------------------------------------------
variable "aws_region" {
  # AWS region to deploy resources.
  # 部署资源的 AWS 区域。
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  # Name of the project.
  # 项目名称。
  description = "Name of the project"
  type        = string
  default     = "data-platform"
}

variable "environment" {
  # Environment name (dev, prod).
  # 环境名称 (dev, prod)。
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
  # The EC2 instance type for MSK broker nodes in development.
  # 开发环境中 MSK Broker 的实例类型。
  description = "The EC2 instance type for MSK broker nodes in development"
  type        = string
}

variable "kafka_version" {
  # Apache Kafka version for the cluster.
  # 集群使用的 Apache Kafka 版本。
  description = "Apache Kafka version for the cluster"
  type        = string
  default     = "3.8.x"
}

variable "flink_output_bucket" {
  # Name of the S3 bucket for Flink output and state.
  # 数据湖 S3 桶名，用于存储 Flink 输出和状态。
  description = "Name of the S3 bucket for Flink output and state"
  type        = string
}

variable "flink_task_cpu" {
  # CPU units for the Flink ECS task.
  # Flink ECS 任务的 CPU 单元数。
  description = "CPU units for the Flink ECS task"
  type        = string
}

variable "flink_task_memory" {
  # Memory (MiB) for the Flink ECS task.
  # Flink ECS 任务的内存大小 (MiB)。
  description = "Memory (MiB) for the Flink ECS task"
  type        = string
}

# ------------------------------------------------------------------------------
# Mock Data Generation Variables
# ------------------------------------------------------------------------------
variable "mock_data_image" {
  # Docker image URI for the mock data generator.
  # Mock 数据生成器的 Docker 镜像地址。
  description = "Docker image URI for the mock data generator"
  type        = string
  default     = "ubuntu:latest"
}

variable "mock_data_schedule" {
  # Schedule for the mock data task (Cron expression).
  # Mock 数据生成任务的 Cron 调度。
  description = "Schedule for the mock data task (Cron expression)"
  type        = string
  default     = null
}

variable "runner_security_group_name" {
  # Name of the security group for the self-hosted runner.
  # Self-hosted Runner 的安全组名称。
  description = "Name of the security group for the self-hosted runner"
  type        = string
}

variable "runner_iam_role_name" {
  # Name of the IAM role for the EC2 runner instance.
  # EC2 Runner 实例的 IAM 角色名称。
  description = "Name of the IAM role for the EC2 runner instance"
  type        = string
}

# ------------------------------------------------------------------------------
# ETL Module Variables (Glue)
# ------------------------------------------------------------------------------
variable "glue_trigger_schedule" {
  # Schedule for the Glue ETL pipeline (Cron expression).
  # ETL 工作流的每日调度时间。
  description = "Schedule for the Glue ETL pipeline (Cron expression)"
  type        = string
}

variable "crawler_schedule" {
  # Schedule for the Glue crawler (Cron expression).
  # Glue Crawler 的调度时间。
  description = "Schedule for the Glue crawler (Cron expression)"
  type        = string
}

# ------------------------------------------------------------------------------
# Monitoring & Alerting
# ------------------------------------------------------------------------------
variable "alert_email" {
  # Email address for receiving system alerts.
  # 接收系统报警的邮箱地址。
  description = "Email address for receiving system alerts"
  type        = string
}