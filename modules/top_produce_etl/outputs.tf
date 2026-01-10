# ------------------------------------------------------------------------------
# Outputs for the Top Produce ETL Module
# ------------------------------------------------------------------------------

output "glue_job_name" {
  # The name of the created AWS Glue job.
  # 创建的 AWS Glue 作业名称。
  description = "The name of the created AWS Glue job."
  value       = aws_glue_job.top_produce_etl_job.name
}

output "glue_job_role_arn" {
  # The ARN of the IAM role created for the Glue job.
  # 为 Glue 作业创建的 IAM 角色 ARN。
  description = "The ARN of the IAM role created for the Glue job."
  value       = aws_iam_role.glue_job_role.arn
}

output "athena_database_name" {
  # The Glue Data Catalog database name.
  # Glue 数据目录数据库名称。
  description = "The Glue Data Catalog database name"
  value       = aws_glue_catalog_database.etl_database.name
}
