# Terraform Backend Configuration for Development Environment
# 开发环境的 Terraform 后端配置

terraform {
  backend "s3" {
    # The S3 bucket you manually create to store tfstate files
    # 你要手动提前创建的 S3 桶，用来存储 tfstate 文件
    bucket = "justin-data-platform-tfstate-bucket-dev"
    # Path/filename in S3
    # 在 S3 里的路径/文件名
    key = "dev/terraform.tfstate"
    # The AWS region where the S3 bucket is located
    # S3 所在的 AWS 区域
    region = "us-east-1"
    # Whether to enable server-side encryption (AES-256)
    # 是否启用服务端加密 (AES-256)
    encrypt = true
    # Use S3 native locking, DynamoDB is no longer needed
    # 使用 S3 原生锁定，不再需要 DynamoDB
    use_lockfile = true
  }
}