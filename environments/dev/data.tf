data "aws_ssm_parameter" "flink_image_url" {
  name = "/data-platform/dev/ingestion/flink_image_url"
}

data "aws_ssm_parameter" "mockdata_image_url" {
  name = "/data-platform/dev/ingestion/mockdata_image_url"
}
