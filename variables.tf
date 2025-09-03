# AWS Region
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

# Project Name
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "data-platform"
}

# Environment
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC CIDR Block
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Availability Zones
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

# EC2 Instance Type
variable "ec2_instance_type" {
  description = "EC2 instance type for compute resources"
  type        = string
  default     = "t3.medium"
}

# ECS Cluster Name
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "data-processing-cluster"
}

# MSK Cluster Name
variable "msk_cluster_name" {
  description = "Name of the MSK cluster"
  type        = string
  default     = "ingestion-kafka-cluster"
}

# Glue Database Name
variable "glue_database_name" {
  description = "Name of the Glue database"
  type        = string
  default     = "etl-database"
}