# kms CMK for data encryption, AES 256 for MSK、S3、EBS、RDS
resource "aws_kms_key" "msk_data_cmk" {
  description = "CMK for MSK data volumes (encryption at rest)"
  policy      = data.aws_iam_policy_document.msk_data_cmk_policy.json

  # 生产常开：true；dev 环境可设 false
  enable_key_rotation = true
  tags = {
    Name = "${var.environment}-msk-data-cmk"
  }
}

# cmk 别名
resource "aws_kms_alias" "msk_data_cmk_alias" {
  name          = "alias/${var.environment}-msk-data-cmk"
  target_key_id = aws_kms_key.msk_data_cmk.key_id
}

# kms CMK for user encryption
resource "aws_kms_key" "msk_secrets_cmk" {
  description = "CMK for MSK SCRAM secrets"
  policy      = data.aws_iam_policy_document.msk_kms_policy.json

  # 生产常开：true；dev 环境可设 false
  enable_key_rotation = true
}
