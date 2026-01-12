# 1. Glue Service Role
# Allows the AWS Glue service to manage resources on behalf of the account.
resource "aws_iam_role" "glue_job_role" {
  name = "${var.project_name}-${var.environment}-glue-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Attach AWS Managed Glue Service Policy
# Provides basic permissions for CloudWatch logging and Glue API interaction.
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 3. Custom S3 Access Policy
# Scoped permissions for reading/writing ETL assets and Data Lake content.
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "glue-s3-access-policy"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Access to scripts, dependencies, and source data.
      {
        Sid    = "AccessEtlAssets"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.etl_assets.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.etl_assets.bucket}/*",
          "arn:aws:s3:::${var.source_s3_bucket_name}",
          "arn:aws:s3:::${var.source_s3_bucket_name}/*"
        ]
      },
      # Access to the destination data lake for ETL output.
      {
        Sid    = "AccessDataLake"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.destination_s3_bucket_name}",
          "arn:aws:s3:::${var.destination_s3_bucket_name}/*"
        ]
      }
    ]
  })
}
