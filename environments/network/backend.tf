# Backend configuration for the new Network Layer.
# 新网络层的后端配置。
terraform {
  backend "s3" {
    # Using the same configuration as the dev environment, only changing the key.
    # 使用与 dev 环境相同的配置，仅更改 key。
    bucket       = "justin-data-platform-tfstate-bucket-dev"
    key          = "network/terraform.tfstate" # Independent state file path / 独立状态文件路径
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}