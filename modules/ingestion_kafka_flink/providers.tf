terraform {
  required_providers {
    # ... a pre-existing provider might be here ...
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.13.0"
    }
  }
}

# Configure the Kafka Provider
provider "kafka" {
  # 因为我们使用 IAM 认证，所以需要引用 MSK 集群提供的 SASL/IAM bootstrap brokers
  bootstrap_servers = split(",", aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam)
  
  # 启用 TLS 加密，MSK 默认启用
  tls_enabled       = true

  # 关键：配置 IAM 认证
  sasl_mechanism    = "aws-iam"
  sasl_aws_region   = var.aws_region
  # 如果您的 Flink 任务需要 Assume Role，可能还需要 sasl_aws_role_arn
  # 但通常在 ECS/EKS 上，任务角色会自动提供凭证，无需额外配置 role_arn
}
