# Development Environment Variables

# AWS Region for development
aws_region = "us-east-1"

# project name
project_name = "data-platform"

# Environment name
environment = "dev"

# --- ingestion 模块变量赋值 ---
kafka_broker_instance_type = "kafka.t3.small"

kafka_version = "3.8.x"

flink_task_cpu = "512"

flink_task_memory = "4096"

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

flink_output_bucket = "justin-data-platform-dev-flink-output-v1"

# 示例：设置为每天凌晨 1 点 (UTC 时间) 运行
# mock_data_schedule = null
# mock_data_schedule = "cron(0 1 * * ? *)"
# 每三分钟触发一次，用于测试。
mock_data_schedule = "cron(0/3 * * * ? *)"

# Name of the security group for the self-hosted runner
runner_security_group_name = "ingestion_ec2_workflow_seflhostedrunner_sg"

runner_iam_role_name = "ingestion_ec2_ec2_role"

# --- top_produce_etl 模块变量赋值 ---
glue_trigger_schedule = "cron(0 2 * * ? *)" # Daily at 2:00 AM UTC
crawler_schedule      = "cron(0 3 * * ? *)" # Daily at 3:00 AM UTC, one hour after the job

# --- Alerting ---
alert_email = "942407990@qq.com"