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

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnets_cidr" {
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "az_count" {
  description = "How many availability zones to use (1-3). Use data source to pick first N AZs."
  type        = number
  default     = 3
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3"
  }
}

# ---ingestion 模块声明变量 ---
variable "kafka_broker_instance_type" {
  description = "dev 环境中 MSK Broker 的实例类型。"
  type        = string
}

variable "ecs_cluster_name_suffix" {
  description = "Cluster name suffix (optional). Full name will be built from project/env."
  type        = string
  default     = "ecs-cluster"
}

# For MSK and Glue we usually don't hardcode full names; we'll build them in locals.
variable "msk_cluster_name_suffix" {
  description = "MSK cluster name suffix"
  type        = string
  default     = "msk-cluster"
}

variable "msk_sg_name_suffix" {
  description = "MSK sg name suffix"
  type        = string
  default     = "msk-dev-sg"
}

variable "msk_scram_name_prefix" {
  description = "MSK scram name prefix"
  type        = string
  default     = "AmazonMSK"
  validation {
    condition     = can(regex("^AmazonMSK", var.msk_scram_name_prefix))
    error_message = "msk_scram_name must start with 'AmazonMSK' as required by MSK SCRAM secret association."
  }
}

variable "msk_scram_name_suffix" {
  description = "MSK scram name suffix"
  type        = string
  default     = "msk-scram-credentials"
}

variable "glue_database_name_suffix" {
  description = "Glue database name suffix"
  type        = string
  default     = "glue_db"
}

variable "kafka_scram_users" {
  description = "Kafka scram users name"
  type        = map(string)
}

variable "msk_logs_bucket" {
  description = "MSK logs s3 bucket"
  type        = string
}

variable "msk_logs_bucket_prefix" {
  description = "MSK logs s3 bucket prefix"
  type        = string
}

variable "flink_image_uri" {
  description = "Flink Docker 镜像 URI"
  type        = string
  default     = "latest"
}

variable "flink_output_bucket" {
  description = "ingestion-flink-output-s3"
  type        = string
}

variable "flink_task_family" {
  description = "data-platform-flink-family"
  type        = string
  default     = "data-platform-dev-flink-family"
}

variable "flink_task_family_suffix" {
  description = "data_platform_flink_task_family_suffix"
  type        = string
  default     = "family"
}

variable "flink_task_cpu" {
  description = "flink_task_cpu"
  type        = string
}

variable "flink_task_memory" {
  description = "flink_task_memory"
  type        = string
}