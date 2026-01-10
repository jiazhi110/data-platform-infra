# Project name
# 项目名称
project_name = "data-platform"

# Environment name
# 环境名称
environment = "network-base"

# AWS region to deploy resources
# 部署资源的 AWS 区域
aws_region = "us-east-1"

# CIDR block for the VPC
# VPC 的 CIDR 块
vpc_cidr = "10.10.0.0/16"

# List of CIDR blocks for public subnets
# 公有子网的 CIDR 块列表
public_subnets_cidr = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

# List of CIDR blocks for private subnets
# 私有子网的 CIDR 块列表
private_subnets_cidr = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]

# Number of availability zones to use
# 使用多少个可用区
az_count = 3