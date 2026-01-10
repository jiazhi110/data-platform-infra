# ------------------------------------------------------------------------------
# Input Variables for the Top Produce ETL Module
# ------------------------------------------------------------------------------

variable "project_name" {
  # The name of the project, used for naming and tagging resources.
  description = "The name of the project, used for naming and tagging resources."
  type        = string
}

variable "environment" {
  # The deployment environment (e.g., 'dev', 'prod').
  description = "The deployment environment (e.g., 'dev', 'prod')."
  type        = string
}

variable "aws_region" {
  # AWS region to deploy resources.
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "glue_version" {
  # The version of AWS Glue to use.
  # 使用的 AWS Glue 版本。
  description = "The version of AWS Glue to use."
  type        = string
  default     = "4.0" 
}

variable "worker_type" {
  # The type of workers that are allocated when a job runs.
  # Glue 任务分配的 Worker 类型（如 G.1X, G.2X）。
  description = "The type of workers that are allocated when a job runs."
  type        = string
  default     = "G.1X" 
}

variable "number_of_workers" {
  # The number of workers of a defined workerType that are allocated when a job runs.
  # 任务运行时的最大 Worker 数量（配合 Auto-scaling 使用）。
  description = "The number of workers of a defined workerType that are allocated when a job runs."
  type        = number
  default     = 10 
}
  
variable "source_s3_bucket_name" {
  # The name of the S3 bucket where the source data is located.
  # 数据来源 S3 桶名称。
  description = "The name of the S3 bucket where the source data is located."
  type        = string
}

variable "destination_s3_bucket_name" {
  # The name of the S3 bucket where the transformed data will be written.
  # 清洗后的数据存储 S3 桶名称。
  description = "The name of the S3 bucket where the transformed data will be written."
  type        = string
}
  
variable "glue_trigger_schedule" {
  # The cron expression for scheduling the workflow (e.g., 'cron(0 12 * * ? *)').
  # 调度任务的 Cron 表达式。
  description = "The cron expression for scheduling the workflow (e.g., 'cron(0 12 * * ? *)')."
  type        = string
  default     = null
}

variable "crawler_schedule" {
  # The cron expression for scheduling the Glue Crawler (Deprecated).
  # 已废弃：Crawler 调度现由 Step Functions 管理。
  description = "The cron expression for scheduling the Glue Crawler (Deprecated)."
  type        = string
  default     = null
}

variable "sns_alert_topic_arn" {
  # The ARN of the SNS topic to send alerts to.
  # 用于发送 ETL 失败通知的 SNS Topic ARN。
  description = "The ARN of the SNS topic to send alerts to."
  type        = string
}