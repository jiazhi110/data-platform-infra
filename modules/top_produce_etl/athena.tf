# ------------------------------------------------------------------------------
# Athena Infrastructure
# ------------------------------------------------------------------------------
# This is a standard, minimal Athena configuration containing two core components:
# 1. S3 Bucket: Specifically for storing Athena query results (CSV files).
# 2. Athena Workgroup: An environment configuration that forces all query results to be saved in the above bucket.
# 这是一个标准的、最简化的 Athena 配置，包含两个核心组件：
# 1. S3 Bucket: 专门用来存放 Athena 的查询结果 (CSV文件)。
# 2. Athena Workgroup: 一个配置环境，强制所有查询结果都存到上面的 Bucket 里。
# ------------------------------------------------------------------------------

# 1. Query Result Storage Bucket
# Athena must have a place to store the result files of "SELECT *".
# We create a separate bucket to keep it isolated from the original data bucket for cleanliness.
# 1. 查询结果存储桶
# Athena 必须有一个地方存放 "SELECT *" 的结果文件。
# 我们创建一个独立的桶，把它和原始数据桶分开，保持整洁。
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.project_name}-${var.environment}-athena-results-${var.aws_region}"
  # Common in dev environments: allow Terraform to destroy non-empty buckets.
  force_destroy = true # 开发环境方便销毁，生产环境建议设为 false

  tags = {
    Name        = "${var.project_name}-athena-results"
  }
}

# Automated Cleanup Policy (Lifecycle Rule) - Mainstream Best Practice
# Query results are usually temporary and rarely kept for years.
# Set to auto-delete after 7 days to save money and avoid junk file accumulation.
# 自动清理策略 (Lifecycle Rule) - 主流最佳实践
# 查询结果通常只是临时看的，没人会保留好几年。
# 设置 7 天后自动删除，帮你省钱，也避免垃圾文件堆积。
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

# Basic Encryption Configuration (Standard)
# 基础加密配置 (Standard)
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block All Public Access (Security Best Practice)
# 阻止所有公共访问 (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "athena_results_block" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Athena Workgroup
# This is the best way to manage Athena query environments.
# It enforces configuration (enforce_workgroup_configuration = true),
# so when you or teammates switch to this Workgroup in the console,
# there's no need to manually fill in the S3 path; queries run directly without errors.
# 2. Athena Workgroup (工作组)
# 这是管理 Athena 查询环境的最佳方式。
# 它强制了配置 (enforce_workgroup_configuration = true)，
# 这样当你或者队友在控制台切换到这个 Workgroup 时，
# 不需要手动填 S3 路径，直接就能跑查询，不会报错。
resource "aws_athena_workgroup" "etl_workgroup" {
  name = "${var.project_name}-${var.environment}-workgroup"

  configuration {
    # Force query results to be stored in the bucket we created above.
    # 强制将查询结果存入我们上面创建的桶
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
      
      encryption_configuration {
        encryption_option = "SSE_S3" # Use S3 managed keys for encryption / 使用 S3 托管密钥进行加密
      }
    }

    # Key Configuration: Force clients to use this Workgroup's settings.
    # This means regardless of who uses this Workgroup, results will go to the same S3 path neatly.
    # 关键配置：强制客户端使用这个 Workgroup 的设置
    # 这意味着无论谁用这个 Workgroup，结果都会整齐地去到同一个 S3 路径
    enforce_workgroup_configuration = true
    
    # Publish CloudWatch metrics for monitoring query data usage (cost control).
    # 发布 CloudWatch 指标，方便监控查询用了多少数据量（省钱用）
    publish_cloudwatch_metrics_enabled = true
  }

  # Allow deletion even if there are unfinished query records.
  force_destroy = true # 允许删除即使里面有未完成的查询记录
  state         = "ENABLED"
}
