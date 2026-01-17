# Region availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Application images managed via SSM Parameter Store
# These parameters are maintained in the Shared layer to persist across daily destroy cycles.
data "aws_ssm_parameter" "flink_image_url" {
  name = data.terraform_remote_state.shared.outputs.flink_image_url_ssm_name
}

data "aws_ssm_parameter" "mockdata_image_url" {
  name = data.terraform_remote_state.shared.outputs.mockdata_image_url_ssm_name
}
