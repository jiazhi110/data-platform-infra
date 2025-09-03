# Top-produce-ETL and Ingestion Kafka Flink Terraform Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region
}

# Example resource - VPC for the infrastructure
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  }
}

# Example resource - S3 Bucket for data storage
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${var.project_name}-${var.environment}-data-bucket"

  tags = {
    Name        = "${var.project_name}-data-bucket"
    Environment = var.environment
  }
}

# Example resource - S3 Bucket for ETL artifacts
resource "aws_s3_bucket" "etl_bucket" {
  bucket = "${var.project_name}-${var.environment}-etl-bucket"

  tags = {
    Name        = "${var.project_name}-etl-bucket"
    Environment = var.environment
  }
}