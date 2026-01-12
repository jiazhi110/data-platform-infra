# ------------------------------------------------------------------------------
# 1. ETL Assets Bucket
# ------------------------------------------------------------------------------
# Bucket for storing ETL scripts, dependencies, and temporary files.
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "etl_assets" {
  bucket        = "${var.project_name}-${var.environment}-etl-assets-${var.aws_region}"
  # force_destroy enabled for dev environments to facilitate cleanup.
  force_destroy = true 

  tags = {
    Name = "${var.project_name}-etl-assets"
  }
}

# Enable S3 versioning for rollback capability of code and dependencies.
resource "aws_s3_bucket_versioning" "etl_assets_versioning" {
  bucket = aws_s3_bucket.etl_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Security Best Practice: Block all public access.
resource "aws_s3_bucket_public_access_block" "etl_assets_block" {
  bucket = aws_s3_bucket.etl_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle management to automatically purge temporary files and old versions.
resource "aws_s3_bucket_lifecycle_configuration" "etl_assets_lifecycle" {
  bucket = aws_s3_bucket.etl_assets.id

  # Rule 1: Cleanup non-current versions after 30 days.
  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule 2: Expire temporary Glue files after 7 days.
  rule {
    id     = "expire-temporary-files"
    status = "Enabled"
    filter {
      prefix = "temporary/"
    }
    expiration {
      days = 7 
    }
  }

  # Rule 3: Expire Spark UI logs after 30 days.
  rule {
    id     = "expire-spark-logs"
    status = "Enabled"
    filter {
      prefix = "spark-logs/"
    }
    expiration {
      days = 30 
    }
  }
}

# ------------------------------------------------------------------------------
# AWS Glue Job
# ------------------------------------------------------------------------------

resource "aws_glue_job" "top_produce_etl_job" {
  name     = "${var.project_name}-${var.environment}-top-produce-etl"
  role_arn = aws_iam_role.glue_job_role.arn

  command {
    # script_location must point to a .py file for proper visibility in AWS Console.
    script_location = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job_runner.py"
    python_version  = "3.9"
  }

  glue_version = var.glue_version

  # Execution and Resource Configuration
  worker_type         = var.worker_type
  number_of_workers   = var.number_of_workers
  timeout             = 60 
  max_retries         = 1    

  # Default Spark script arguments
  default_arguments = {
    # System Arguments
    "--extra-py-files"                   = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/job.zip"
    "--config_path"                      = "s3://${aws_s3_bucket.etl_assets.bucket}/scripts/config/config_dev.yaml"
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.etl_assets.bucket}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.etl_assets.bucket}/temporary/"

    # Job Bookmarks: Enable incremental data processing.
    "--job-bookmark-option"              = "job-bookmark-enable"

    # Auto Scaling: Dynamically adjust workers based on load.
    "--enable-auto-scaling"              = "true"

    # User Arguments
    "--ENV"                              = var.environment
    "--S3_SOURCE_PATH"                   = "s3://${var.source_s3_bucket_name}/user_action/"
    "--S3_OUTPUT_PATH"                   = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-top-produce-etl"
  }
}

# CloudWatch Log Group for Glue Job monitoring.
resource "aws_cloudwatch_log_group" "glue_logs" {
  name              = "/aws-glue/jobs/${aws_glue_job.top_produce_etl_job.name}" 
  retention_in_days = 14 
}

# Define Glue Database logical container.
resource "aws_glue_catalog_database" "etl_database" {
  name = "${var.project_name}-${var.environment}-db" 
}

# ------------------------------------------------------------------------------
# 5. AWS Glue Crawler (Automated Metadata Discovery)
# ------------------------------------------------------------------------------
resource "aws_glue_crawler" "etl_crawler" {
  name          = "${var.project_name}-${var.environment}-crawler"
  database_name = aws_glue_catalog_database.etl_database.name
  role          = aws_iam_role.glue_job_role.arn 

  s3_target {
    path = "s3://${var.destination_s3_bucket_name}/batch_output/"
  }

  # Schema Evolution & Partition Management
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      # InheritFromTable: ensures partition metadata matches the table definition.
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
      # MergeNewColumns: allows schema evolution without deleting existing columns.
      Tables     = { AddOrUpdateBehavior = "MergeNewColumns" }
    }
  })
}

# ------------------------------------------------------------------------------
# 5.1 AWS Glue Catalog Table (Bootstrap Table)
# ------------------------------------------------------------------------------
# Pre-defines core fields to resolve Data Quality Ruleset dependencies.
# Other fields are discovered and merged by the Crawler at runtime.
# ------------------------------------------------------------------------------
resource "aws_glue_catalog_table" "batch_output_table" {
  name          = "batch_output"
  database_name = aws_glue_catalog_database.etl_database.name
  table_type    = "EXTERNAL_TABLE" 

  storage_descriptor {
    location      = "s3://${var.destination_s3_bucket_name}/batch_output/"
    input_format  = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat"

    ser_de_info {
      serialization_library = "org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe"
      parameters = {
        "serialization.format" = "1" 
      }
    }

    columns {
      name    = "area_name"
      type    = "string"
      comment = "Bootstrap column - others discovered by crawler"
    }
  }

  parameters = {
    "classification" = "parquet"
  }
}

# ------------------------------------------------------------------------------
# 6. AWS Glue Data Quality (Data Governance)
# ------------------------------------------------------------------------------
resource "aws_glue_data_quality_ruleset" "data_quality_check" {
  name        = "${var.project_name}-${var.environment}-dq-rules"
  description = "Validate data quality for the batch output table"

  target_table {
    database_name = aws_glue_catalog_database.etl_database.name
    table_name    = aws_glue_catalog_table.batch_output_table.name 
  }

  # DQDL Ruleset for automated data validation.
  ruleset = <<EOF
    Rules = [
        # Validate that ETL logic produced data.
        RowCount > 0,

        # Core dimension completeness check.
        IsComplete "area_name",
        IsComplete "produce_name",

        # Business logic validation.
        ColumnValues "total_clicks" > 0
    ]
EOF

  tags = {
    Name = "${var.project_name}-dq-rules"
  }
}
