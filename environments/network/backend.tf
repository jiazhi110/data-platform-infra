# Backend configuration for the Network Layer.
terraform {
  backend "s3" {
    bucket       = "justin-data-platform-tfstate-bucket-dev"
    # Independent state path for network infrastructure.
    key          = "network/terraform.tfstate" 
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
