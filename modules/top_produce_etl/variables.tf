# ------------------------------------------------------------------------------
# Input Variables for the Top Produce ETL Module
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Project name, used for naming and tagging resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)."
  type        = string
}

variable "aws_region" {
  description = "AWS region for resource deployment."
  type        = string
  default     = "us-east-1"
}

variable "glue_version" {
  description = "AWS Glue version."
  type        = string
  default     = "4.0" 
}

variable "worker_type" {
  description = "Glue worker type (e.g., G.1X, G.2X)."
  type        = string
  default     = "G.1X" 
}

variable "number_of_workers" {
  description = "Maximum number of workers for Glue auto-scaling."
  type        = number
  default     = 10 
}
  
variable "source_s3_bucket_name" {
  description = "Source S3 bucket for the ETL pipeline."
  type        = string
}

variable "destination_s3_bucket_name" {
  description = "Destination S3 bucket for transformed data."
  type        = string
}
  
variable "glue_trigger_schedule" {
  description = "Cron schedule for the ETL workflow."
  type        = string
  default     = null
}

variable "crawler_schedule" {
  description = "Cron schedule for the Glue Crawler (Deprecated)."
  type        = string
  default     = null
}

variable "sns_alert_topic_arn" {
  description = "SNS topic ARN for alerting."
  type        = string
}
