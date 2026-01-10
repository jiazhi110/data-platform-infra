terraform {
  # Minimum Terraform CLI version required
  # 锁定 Terraform CLI 的最低版本
  required_version = "~> 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Default tags applied to all resources managed by this provider
  # 默认标签将应用于此 Provider 管理的所有资源
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}