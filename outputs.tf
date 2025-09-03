# VPC ID Output
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main_vpc.id
}

# VPC CIDR Block Output
output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main_vpc.cidr_block
}

# Data Bucket Name Output
output "data_bucket_name" {
  description = "Name of the S3 bucket for data storage"
  value       = aws_s3_bucket.data_bucket.bucket
}

# ETL Bucket Name Output
output "etl_bucket_name" {
  description = "Name of the S3 bucket for ETL artifacts"
  value       = aws_s3_bucket.etl_bucket.bucket
}

# Data Bucket ARN Output
output "data_bucket_arn" {
  description = "ARN of the S3 bucket for data storage"
  value       = aws_s3_bucket.data_bucket.arn
}

# ETL Bucket ARN Output
output "etl_bucket_arn" {
  description = "ARN of the S3 bucket for ETL artifacts"
  value       = aws_s3_bucket.etl_bucket.arn
}

# AWS Region Output
output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}