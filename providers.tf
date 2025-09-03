# AWS Provider Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default AWS Provider
provider "aws" {
  region = var.aws_region

  # Profile is optional - can be specified via AWS_PROFILE environment variable
  # profile = "default"
}

# Additional AWS Provider for different region (example)
# provider "aws" {
#   alias  = "us-east-1"
#   region = "us-east-1"
# }

# AWS Provider with assume role (example)
# provider "aws" {
#   alias  = "production"
#   region = var.aws_region
# 
#   assume_role {
#     role_arn = "arn:aws:iam::123456789012:role/terraform-role"
#   }
# }