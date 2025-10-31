# Terraform Backend Configuration for Development Environment

terraform {
  backend "s3" {
    bucket         = "justin-data-platform-tfstate-bucket-dev" # 你要手动提前创建的 S3 桶，用来存储 tfstate 文件
    key            = "dev/terraform.tfstate"                   # 在 S3 里的路径/文件名
    region         = "us-east-1"                               # S3 所在的 AWS 区域
    encrypt        = true                                      # 是否启用服务端加密 (AES-256)
    dynamodb_table = "terraform-state-lock-dev"                # DynamoDB 表，用来做“状态锁定”
  }
}
