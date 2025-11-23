# ------------------------------------------------------------------------------
# Outputs for the Top Produce ETL Module
# ------------------------------------------------------------------------------

output "glue_job_name" {
  description = "The name of the created AWS Glue job."
  value       = aws_glue_job.top_produce_etl_job.name
}

output "glue_job_role_arn" {
  description = "The ARN of the IAM role created for the Glue job."
  value       = aws_iam_role.glue_job_role.arn
}
