# Networking Module Variables
# 网络模块变量

variable "project_name" {
  # Name of the project.
  # 项目名称。
  description = "Name of the project"
  type        = string
}

variable "environment" {
  # Environment name (dev, prod).
  # 环境名称 (dev, prod)。
  description = "Environment name (dev, prod)"
  type        = string
}

variable "aws_region" {
  # AWS region to deploy resources.
  # 部署资源的 AWS 区域。
  description = "AWS region to deploy resources"
  type        = string
  # Add default value to prevent empty region errors if tfvars are not loaded.
  # 增加默认值，防止由于未加载 tfvars 导致的区域为空错误
  default = "us-east-1"
}

variable "vpc_cidr" {
  # CIDR block for the VPC.
  # VPC 的 CIDR 块 (例如 10.0.0.0/16)。
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets_cidr" {
  # List of CIDR blocks for public subnets.
  # 公有子网的 CIDR 块列表。
  description = "List of CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnets_cidr" {
  # List of CIDR blocks for private subnets.
  # 私有子网的 CIDR 块列表。
  description = "List of CIDR blocks for private subnets."
  type        = list(string)
}

variable "az_count" {
  # How many availability zones to use (1-3).
  # 使用多少个可用区 (1-3)。
  description = "How many availability zones to use (1-3). Use data source to pick first N AZs."
  type        = number
  default     = 3
  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "az_count must be between 1 and 3"
  }
}
