# Development Environment Variables
# 开发环境变量

# AWS Region for development
# 开发环境的 AWS 区域
aws_region = "us-east-1"

# Project name
# 项目名称
project_name = "data-platform"

# Environment name
# 环境名称
environment = "dev"

# --- ingestion module variable assignments ---
# --- ingestion 模块变量赋值 ---
kafka_broker_instance_type = "kafka.t3.small"

kafka_version = "3.8.x"

flink_task_cpu = "512"

flink_task_memory = "4096"

flink_output_bucket = "justin-data-platform-dev-flink-output-v1"

# Example: Set to run daily at 1:00 AM (UTC time)
# 示例：设置为每天凌晨 1 点 (UTC 时间) 运行
# mock_data_schedule = null
# mock_data_schedule = "cron(0 1 * * ? *)"
# Triggered every three minutes for testing.
# 每三分钟触发一次，用于测试。
mock_data_schedule = "cron(0/3 * * * ? *)"

# Name of the security group for the self-hosted runner
# Self-hosted Runner 的安全组名称
runner_security_group_name = "ingestion_ec2_workflow_seflhostedrunner_sg"

# Name of the IAM role for the EC2 runner instance
# EC2 Runner 实例的 IAM 角色名称
runner_iam_role_name = "ingestion_ec2_ec2_role"

# --- top_produce_etl module variable assignments ---
# --- top_produce_etl 模块变量赋值 ---
glue_trigger_schedule = "cron(0 2 * * ? *)" # Daily at 2:00 AM UTC
crawler_schedule      = "cron(0 3 * * ? *)" # Daily at 3:00 AM UTC, one hour after the job, but canceled, and replace by SFN

# --- Alerting ---
# --- 报警配置 ---
alert_email = "942407990@qq.com"
