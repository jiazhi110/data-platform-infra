# Staging Environment Variables Override

# AWS Region for staging
aws_region = "us-west-2"

# Environment name
environment = "staging"

# VPC CIDR for staging
vpc_cidr = "10.20.0.0/16"

# EC2 Instance Type for staging
ec2_instance_type = "t3.large"

# ECS Cluster Name for staging
ecs_cluster_name = "data-processing-staging-cluster"

# MSK Cluster Name for staging
msk_cluster_name = "ingestion-kafka-staging-cluster"

# Glue Database Name for staging
glue_database_name = "etl-staging-database"