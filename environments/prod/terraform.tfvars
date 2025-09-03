# Production Environment Variables Override

# AWS Region for production
aws_region = "us-west-2"

# Environment name
environment = "prod"

# VPC CIDR for production
vpc_cidr = "10.30.0.0/16"

# EC2 Instance Type for production
ec2_instance_type = "t3.xlarge"

# ECS Cluster Name for production
ecs_cluster_name = "data-processing-prod-cluster"

# MSK Cluster Name for production
msk_cluster_name = "ingestion-kafka-prod-cluster"

# Glue Database Name for production
glue_database_name = "etl-prod-database"