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
    condition     = contains(["dev","prod"], var.environment)
    error_message = "environment must be one of: dev, prod"
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

# --- 网络相关的输入 ---
# 这些值将由 networking 模块的输出提供。

variable "vpc_id" {
  description = "服务需要部署在哪个 VPC 中。"
  type        = string
}

variable "private_subnet_ids" {
  description = "MSK Kafka 集群需要使用的私有子网 ID 列表。"
  type        = list(string)
}

# --- MSK Kafka EC2, 为了后续在EC2上面执行ingest ---

# variable "ec2_instance_type" {
#   description = "EC2 instance type for compute resources. Avoid t2 family by policy."
#   type        = string
#   default     = "t3.medium"
# }

# variable "ecs_cluster_name_suffix" {
#   description = "Cluster name suffix (optional). Full name will be built from project/env."
#   type        = string
#   default     = "ecs-cluster"
# }

# --- MSK Kafka 相关的输入 ---

variable "kafka_broker_instance_type" {
  description = "MSK Broker 节点的 EC2 实例类型。"
  type        = string
  default     = "kafka.t3.small" # dev 环境用小一点的省钱
}

variable "kafka_version" {
  description = "Apache Kafka 的版本。"
  type        = string
}

variable "msk_cluster_name" {
  description = "MSK cluster name"
  type        = string
  default     = "msk-cluster"
}

variable "msk_sg_name" {
  type        = string
  description = "Name of the MSK security group"
}

variable "msk_scram_name" {
  type        = string
  description = "Name of the MSK SCRAM secret"
  validation {
    condition     = can(regex("^AmazonMSK_", var.msk_scram_name))
    error_message = "msk_scram_name must start with AmazonMSK_"
  }
}

variable "kafka_scram_users" {
  type        = map(string)
  description = "SCRAM username/password map"
}

# instead of dynamic ECR sg
# variable "client_security_group_ids" {
#   type    = list(string)
#   default = []   # 这里可以留空，或者在 tfvars 里填
# }

variable "msk_logs_bucket" {
  description = "MSK logs s3 bucket"
  type        = string
}

variable "msk_logs_bucket_prefix" {
  description = "MSK logs s3 bucket prefix"
  type        = string
}

variable "flink_output_bucket" {
  description = "ingestion-flink-output-s3"
  type        = string
}

variable "flink_task_family" {
  description = "data-platform-flink-family"
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

variable "flink_image_uri" {
  description = "Flink Docker 镜像 URI"
  type        = string
  default     = "latest"
}