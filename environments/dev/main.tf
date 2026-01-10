# Development Environment - Data Platform Infrastructure
# 开发环境 - 数据平台基础设施

# --- Network Layer (Remote State) ---
# --- 网络层 (远程状态) ---
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket       = "justin-data-platform-tfstate-bucket-dev"
    key          = "network/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# --- Monitoring Module ---
# --- 监控模块 ---
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}

# --- Ingestion Module (Kafka + Flink) ---
# --- 摄取模块 (Kafka + Flink) ---
module "ingestion" {
  source = "../../modules/ingestion_kafka_flink"

  # --- Common Inputs ---
  # --- 通用输入 ---
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # --- Network Inputs ---
  # --- 网络输入 ---
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # --- Module Specific Inputs ---
  # --- 模块特定输入 ---
  kafka_broker_instance_type = var.kafka_broker_instance_type
  kafka_version              = var.kafka_version

  flink_task_cpu      = var.flink_task_cpu
  flink_task_memory   = var.flink_task_memory
  flink_image_url     = data.aws_ssm_parameter.flink_image_url.value
  flink_output_bucket = var.flink_output_bucket

  mockdata_image_url = data.aws_ssm_parameter.mockdata_image_url.value
  mock_data_schedule = var.mock_data_schedule

  runner_security_group_name = var.runner_security_group_name
  runner_iam_role_name       = var.runner_iam_role_name

  # --- Alerting ---
  # --- 报警配置 ---
  sns_alert_topic_arn = module.monitoring.sns_topic_arn
}

# --- ETL Module (Glue) ---
# --- ETL 模块 (Glue) ---
module "top_produce_etl" {
  source = "../../modules/top_produce_etl"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Source: Flink Output Bucket
  # 数据源：Flink 输出桶
  source_s3_bucket_name = module.ingestion.flink_output_bucket
  # Destination: Same bucket (different prefix)
  # 目的地：同一个桶 (不同的前缀)
  destination_s3_bucket_name = module.ingestion.flink_output_bucket

  glue_trigger_schedule = var.glue_trigger_schedule
  crawler_schedule      = var.crawler_schedule

  # --- Alerting ---
  # --- 报警配置 ---
  sns_alert_topic_arn = module.monitoring.sns_topic_arn
}