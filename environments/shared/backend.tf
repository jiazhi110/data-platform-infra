terraform {
  backend "s3" {
    bucket       = "justin-data-platform-tfstate-bucket-dev"
    key          = "shared/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
