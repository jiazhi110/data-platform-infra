# --- Athena Infrastructure ---
# Minimal Athena configuration for querying the data lake.

# 1. Query Result Storage Bucket
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.project_name}-${var.environment}-athena-results-${var.aws_region}"
  force_destroy = true 

  tags = {
    Name = "${var.project_name}-athena-results"
  }
}

# Automated Cleanup: expire query results after 7 days to minimize storage costs.
resource "aws_s3_bucket_lifecycle_configuration" "athena_results_lifecycle" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-old-results"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "athena_results_block" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Athena Workgroup
# Manages query execution settings. Enforcing configuration ensures all queries 
# use the same result bucket regardless of client-side settings.
resource "aws_athena_workgroup" "etl_workgroup" {
  name = "${var.project_name}-${var.environment}-workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
      encryption_configuration {
        encryption_option = "SSE_S3" 
      }
    }

    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics_enabled = true
  }

  force_destroy = true 
  state         = "ENABLED"
}