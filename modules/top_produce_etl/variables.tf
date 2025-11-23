# ------------------------------------------------------------------------------
# Input Variables for the Top Produce ETL Module
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "The name of the project, used for naming and tagging resources."
  type        = string
}

variable "environment" {
  description = "The deployment environment (e.g., 'dev', 'prod')."
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

# 在etl_assets s3 中 declared了。
# variable "glue_script_location" {
#   description = "The S3 path to the Glue ETL script (e.g., 's3://your-bucket/scripts/etl.py')."
#   type        = string
# }

variable "glue_version" {
  description = "The version of AWS Glue to use."
  type        = string
  default     = "4.0" # "4.0" is a good default, supporting Spark 3.3 and Python 3.10
}

variable "worker_type" {
  description = "The type of workers that are allocated when a job runs."
  type        = string
  default     = "G.1X" # A standard worker type
}

variable "number_of_workers" {
  description = "The number of workers of a defined workerType that are allocated when a job runs."
  type        = number
    default     = 10 # A reasonable default for a small to medium job
  }
  
variable "source_s3_bucket_name" {
  description = "The name of the S3 bucket where the source data is located."
  type        = string
}

variable "destination_s3_bucket_name" {
  description = "The name of the S3 bucket where the transformed data will be written."
  type        = string
}
  
variable "glue_trigger_schedule" {
  description = "The cron expression for scheduling the Glue job (e.g., 'cron(0 12 * * ? *)'). If null, the trigger is disabled."
  type        = string
  default     = null
}

variable "crawler_schedule" {
  description = "The cron expression for scheduling the Glue Crawler (e.g., 'cron(0 3 * * ? *)'). If null, the crawler is not scheduled."
  type        = string
  default     = null
}
      