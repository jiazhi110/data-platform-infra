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

# Refactor: Commenting out network-related variables as they are now managed by the network layer.
# variable "vpc_cidr" {
#   description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
#   type        = string
#   default     = "10.0.0.0/16"
# }
# 
# variable "public_subnets_cidr" {
#   description = "List of CIDR blocks for public subnets."
#   type        = list(string)
# }
# 
# variable "private_subnets_cidr" {
#   description = "List of CIDR blocks for private subnets."
#   type        = list(string)
# }
# 
# variable "az_count" {
#   description = "How many availability zones to use (1-3). Use data source to pick first N AZs."
#   type        = number
#   default     = 3
#   validation {
#     condition     = var.az_count >= 1 && var.az_count <= 3
#     error_message = "az_count must be between 1 and 3"
#   }
# }

# variable "public_subnet_ids" {
#   description = "List of public subnet IDs for the VPC."
#   type        = list(string)
# }
# 
# variable "private_subnet_ids" {
#   description = "List of private subnet IDs for the VPC."
#   type        = list(string)
# }

# ---ingestion 模块声明变量 ---
variable "kafka_broker_instance_type" {
  description = "dev 环境中 MSK Broker 的实例类型。"
  type        = string
}

variable "kafka_version" {
  description = "Apache Kafka 的版本。"
  type        = string
  default     = "3.8.x"
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

# variable "msk_scram_name_prefix" {
#   description = "MSK scram name prefix"
#   type        = string
#   default     = "AmazonMSK"
#   validation {
#     condition     = can(regex("^AmazonMSK", var.msk_scram_name_prefix))
#     error_message = "msk_scram_name must start with 'AmazonMSK' as required by MSK SCRAM secret association."
#   }
# }

# variable "msk_scram_name_suffix" {
#   description = "MSK scram name suffix"
#   type        = string
#   default     = "msk-scram-credentials"
# }

variable "glue_database_name_suffix" {
  description = "Glue database name suffix"
  type        = string
  default     = "glue_db"
}

# variable "kafka_scram_user" {
#   description = "Kafka scram users name"
#   type = object({
#     username = string
#     password = string
#   })
#   # 标记这个变量或输出是“敏感信息”（Sensitive），Terraform 就不会在终端、日志或 plan/apply 输出结果里明文显示它的值。
#   sensitive = false
# }


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

# --- Mock Data Generation ---

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
