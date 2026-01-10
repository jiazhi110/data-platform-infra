# Fetch available availability zones in the current region.
# 获取当前区域内所有可用的可用区。
data "aws_availability_zones" "available" {
  state = "available"
}

# Fetch the ECR image URL for the Flink job from SSM Parameter Store.
# 从 SSM Parameter Store 获取 Flink 任务的 ECR 镜像 URL。
data "aws_ssm_parameter" "flink_image_url" {
  name = "/data-platform/dev/ingestion/flink_job_image_url"
}

# Fetch the ECR image URL for the Mock Data generator from SSM Parameter Store.
# 从 SSM Parameter Store 获取 Mock 数据生成器的 ECR 镜像 URL。
data "aws_ssm_parameter" "mockdata_image_url" {
  name = "/data-platform/dev/ingestion/mockdata_producer_image_url"
}