# ------------------------------------------------------------------------------
# Outputs for the Top Produce ETL Module
# ------------------------------------------------------------------------------

output "glue_job_name" {
  description = "The name of the AWS Glue job."
  value       = aws_glue_job.top_produce_etl_job.name
}

output "glue_job_role_arn" {
  description = "The ARN of the IAM role for the Glue job."
  value       = aws_iam_role.glue_job_role.arn
}

output "athena_database_name" {
  description = "The Glue Data Catalog database name."
  value       = aws_glue_catalog_database.etl_database.name
}