# Development Environment Variables

# AWS Region for development
aws_region = "us-east-1"

# project name
project_name = "data-platform"

# Environment name
environment = "dev"

#   首先，您需要从 IANA (互联网号码分配局) 指定的三个私有 IPv4 地址块中选择一个。您不能随便编一个地址。

#    * A 类: 10.0.0.0 to 10.255.255.255 (CIDR: 10.0.0.0/8)
#        * 特点：地址空间最大，非常灵活。
#        * 最常用：这是绝大多数公司和云项目的首选。因为它足够大，可以轻松地为不同的部门、环境、区域划分出完全不冲突的子范围。

#    * B 类: 172.16.0.0 to 172.31.255.255 (CIDR: 172.16.0.0/12)
#        * 特点：大小适中。
#        * 常用度：也比较常用。AWS 的默认 VPC 就喜欢用这个范围内的地址（比如 172.31.0.0/16）。

#    * C 类: 192.168.0.0 to 192.168.255.255 (CIDR: 192.168.0.0/16)
#        * 特点：地址空间最小。
#        * 常用度：在企业级项目中较少作为 VPC 的主 CIDR，因为它太小了。这个地址段更常见于家庭路由器、小型办公室网络或 Docker 容器网络。

# VPC CIDR for development
vpc_cidr = "10.10.0.0/16"

public_subnets_cidr = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

private_subnets_cidr = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]

# AZ count for development
az_count = 3

# --- ingestion 模块变量赋值 ---
kafka_broker_instance_type = "kafka.t3.small"

kafka_version = "3.8.x"

# EC2 Instance Type for development
# ec2_instance_type = "t3.medium"

# ECS Cluster Name for development
# ecs_cluster_name_suffix = "ecs-dev-cluster"

# MSK Cluster Name for development
msk_cluster_name_suffix = "msk-dev-cluster"

# MSK security group Name for development
msk_sg_name_suffix = "msk-dev-sg"

# MSK security scram credentials Name for development
# msk_scram_name_suffix = "msk-scram-credentials"

# MSK security scram credentials Name for development
# msk_scram_name_prefix = "AmazonMSK"

# ECR task definition Name for development
flink_task_family_suffix = "family"

# ECR task cpu for development 512:.5cpu
flink_task_cpu = "512"

# ECR task memory for development 3072:3GB
flink_task_memory = "3072"

# Glue Database Name for development
# glue_database_name_suffix = "glue_dev_db"

# --- 新增：为 SCRAM 用户提供具体的值 ---
# 在真实项目中，这些密码应该使用更安全的方式注入，
# 但对于 dev 环境，写在这里是可接受的。
# 确保使用强密码！
# kafka_scram_user = {
#   "username" = "flink_user"
#   "password" = "DevFlinkUserPassword123!"
# }

# instead of dynamic ECR sg
# client_security_group_ids = [
#   "sg-0abc123456789def0" # EC2/ECS/Glue/Lambda的安全组ID
# ]

msk_logs_bucket_prefix = "msk/dev"

flink_output_bucket = "ingestion-flink-output-s3"

# 示例：设置为每天凌晨 1 点 (UTC 时间) 运行
# mock_data_schedule = null
# mock_data_schedule = "cron(0 1 * * ? *)"
# 每三分钟触发一次，用于测试。
mock_data_schedule = "cron(0/3 * * * ? *)"

# Name of the security group for the self-hosted runner
runner_security_group_name = "ingestion_ec2_workflow_seflhostedrunner"