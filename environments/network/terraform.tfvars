# Project name
project_name         = "data-platform"

# Environment identifier
environment          = "network-base"

# Target deployment region
aws_region           = "us-east-1"

# VPC address space
vpc_cidr             = "10.10.0.0/16"

# Public tier subnets
public_subnets_cidr  = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]

# Private tier subnets
private_subnets_cidr = ["10.10.11.0/24", "10.10.12.0/24", "10.10.13.0/24"]

# Reliability: distribution across AZs
az_count             = 3
