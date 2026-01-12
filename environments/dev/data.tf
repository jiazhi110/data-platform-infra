# Region availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Application images managed via SSM Parameter Store
data "aws_ssm_parameter" "flink_image_url" {
  name = "/data-platform/dev/ingestion/flink_job_image_url"
}

data "aws_ssm_parameter" "mockdata_image_url" {
  name = "/data-platform/dev/ingestion/mockdata_producer_image_url"
}
