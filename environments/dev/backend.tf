# Terraform Backend Configuration for Development Environment

terraform {
  backend "s3" {
    bucket  = "justin-data-platform-tfstate-bucket-dev"
    key     = "dev/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    # Use native S3 state locking.
    use_lockfile = true
  }
}
