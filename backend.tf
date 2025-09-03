# Terraform Backend Configuration
# Uncomment and configure according to your needs

# S3 Backend for state storage
# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state-bucket"
#     key            = "data-platform/terraform.tfstate"
#     region         = "us-west-2"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# Local Backend (for development only)
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}