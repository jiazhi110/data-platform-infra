# Development Environment - Data Platform Infrastructure

# Module 1: Networking
module "networking" {
  source = "../../modules/networking"

  vpc_cidr             = var.vpc_cidr
  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  azs                  = local.azs
  az_count             = var.az_count
  private_subnets_cidr = var.private_subnets_cidr
  public_subnets_cidr  = var.public_subnets_cidr
}

# Module 2: Ingestion Kafka Flink ---
module "ingestion" {
  source = "../../modules/ingestion_kafka_flink"

  # --- 传入通用变量 ---
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # --- 关键：连接两个模块 ---
  # 将 networking 模块的输出，作为 ingestion 模块的输入。
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids

  # --- 传入 ingestion 模块专属的变量 ---
  kafka_broker_instance_type = var.kafka_broker_instance_type
  kafka_version              = var.kafka_version
  msk_cluster_name           = local.msk_cluster_name
  msk_sg_name                = local.msk_sg_name
  msk_scram_name             = local.msk_scram_name
  kafka_scram_user           = var.kafka_scram_user
  msk_logs_bucket            = var.msk_logs_bucket
  msk_logs_bucket_prefix     = var.msk_logs_bucket_prefix
  flink_task_family          = local.flink_task_family
  flink_task_cpu             = var.flink_task_cpu
  flink_task_memory          = var.flink_task_memory

  flink_image_uri     = var.flink_image_uri
  flink_output_bucket = var.flink_output_bucket


}

# # Module 3: Top Produce ETL
# module "top_produce_etl" {
#   source = "../../modules/top_produce_etl"

#   project_name        = var.project_name
#   environment         = var.environment
#   vpc_id              = module.networking.vpc_id
#   subnet_ids          = module.networking.private_subnets
#   glue_database_name  = local.glue_database_name
# }