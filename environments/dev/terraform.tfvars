# Development Environment Variables

# AWS Region for development
aws_region = "us-east-1"

# Environment name
environment = "dev"

# VPC CIDR for development
vpc_cidr = "10.10.0.0/16"

public_subnets_cidr  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

private_subnets_cidr = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]

# AZ count for development
az_count = 3

# --- ingestion 模块变量赋值 ---
kafka_broker_instance_type = "kafka.t3.small"

# EC2 Instance Type for development
# ec2_instance_type = "t3.medium"

# ECS Cluster Name for development
# ecs_cluster_name_suffix = "ecs-dev-cluster"

# MSK Cluster Name for development
msk_cluster_name_suffix = "msk-dev-cluster"

# MSK security group Name for development
msk_sg_name_suffix = "msk-dev-sg"

# MSK security scram credentials Name for development
msk_scram_name_suffix = "msk-scram-credentials"

# MSK security scram credentials Name for development
msk_scram_name_prefix = "AmazonMSK"

# Glue Database Name for development
# glue_database_name_suffix = "glue_dev_db"

# --- 新增：为 SCRAM 用户提供具体的值 ---
# 在真实项目中，这些密码应该使用更安全的方式注入，
# 但对于 dev 环境，写在这里是可接受的。
# 确保使用强密码！
kafka_scram_users = {
  "flink_user" = "DevFlinkUserPassword123!"
  "test_user"  = "DevTestUserPassword456!"
}

client_security_group_ids = [
  "sg-0abc123456789def0"  # EC2/ECS/Glue/Lambda的安全组ID
]

# cloudwatch s3 logs
msk_logs_bucket = "my-justin-data-platform-logs-bucket"

msk_logs_bucket_prefix = "msk/dev"

# 重要提示：在生产环境（prod/terraform.tfvars）中，应严格避免使用 "latest"，而是使用如 "v1.0.0" 这样的固定版本标签。
producer_image_tag = "latest"

flink_output_bucket = "ingestion-flink-output-s3"