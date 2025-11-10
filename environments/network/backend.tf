# Backend configuration for the new Network Layer.
terraform {
  backend "s3" {
    # Using the same configuration as the dev environment, only changing the key.
    bucket       = "justin-data-platform-tfstate-bucket-dev"
    key          = "network/terraform.tfstate" # Independent state file path
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
