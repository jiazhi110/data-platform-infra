# --- Development Environment Configurations ---

aws_region   = "us-east-1"
project_name = "data-platform"
environment  = "dev"

# Ingestion configurations
kafka_broker_instance_type = "kafka.t3.small"
kafka_version              = "3.8.x"
flink_task_cpu             = "512"
flink_task_memory          = "4096"
flink_output_bucket        = "justin-data-platform-dev-flink-output-v1"

# Mock Data Generation: triggered every 3 minutes for testing purposes.
mock_data_schedule = "cron(0/3 * * * ? *)"

# Self-hosted Runner infrastructure
runner_security_group_name = "ingestion_ec2_workflow_seflhostedrunner_sg"
runner_iam_role_name       = "ingestion_ec2_ec2_role"

# Batch Processing schedule (managed by SFN orchestration)
glue_trigger_schedule = "cron(0 2 * * ? *)"
crawler_schedule      = "cron(0 3 * * ? *)"

# Alert notification endpoint
alert_email = "942407990@qq.com"