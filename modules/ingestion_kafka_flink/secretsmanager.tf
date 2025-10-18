# --- AWS Secrets Manager: 存储 Kafka 用户凭证 ---
# 这是标准的做法：将敏感信息（如密码）存储在 Secrets Manager 中，而不是硬编码在代码里。

# secret key
resource "aws_secretsmanager_secret" "msk_scram_credentials" {
  name        = var.msk_scram_name
  description = "SCRAM credentials for MSK cluster"
  kms_key_id   = aws_kms_key.msk_secrets_cmk.arn
}

# 将传入的用户名密码变量（一个 map）转换为 Secrets Manager 所需的 JSON 字符串格式。
resource "aws_secretsmanager_secret_version" "msk_scram_credentials_version" {
  secret_id     = aws_secretsmanager_secret.msk_scram_credentials.id
  secret_string = jsonencode({
    username = var.kafka_scram_user.username
    password = var.kafka_scram_user.password
  })
}
