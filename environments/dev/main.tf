# Development Environment - Data Platform Infrastructure

# --- Network Layer (Remote State) ---
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
module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
}

# --- Ingestion Module (Kafka + Flink) ---
module "ingestion" {
  source = "../../modules/ingestion_kafka_flink"

  # --- Common Inputs ---
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # --- Network Inputs ---
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids

  # --- Module Specific Inputs ---
  kafka_broker_instance_type = var.kafka_broker_instance_type
  kafka_version              = var.kafka_version
  
  flink_task_cpu             = var.flink_task_cpu
  flink_task_memory          = var.flink_task_memory
  flink_image_url            = data.aws_ssm_parameter.flink_image_url.value
  flink_output_bucket        = var.flink_output_bucket
  
  mockdata_image_url         = data.aws_ssm_parameter.mockdata_image_url.value
  mock_data_schedule         = var.mock_data_schedule
  
  runner_security_group_name = var.runner_security_group_name
  runner_iam_role_name       = var.runner_iam_role_name
  
  # --- Alerting ---
  sns_alert_topic_arn        = module.monitoring.sns_topic_arn
}

# --- ETL Module (Glue) ---
module "top_produce_etl" {
  source = "../../modules/top_produce_etl"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Source: Flink Output Bucket
  source_s3_bucket_name = module.ingestion.flink_output_bucket
  # Destination: Same bucket (different prefix)
  destination_s3_bucket_name = module.ingestion.flink_output_bucket

  glue_trigger_schedule = var.glue_trigger_schedule
  crawler_schedule      = var.crawler_schedule
  
  # --- Alerting ---
  sns_alert_topic_arn   = module.monitoring.sns_topic_arn
}