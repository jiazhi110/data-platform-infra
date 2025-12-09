# ------------------------------------------------------------------------------
# Athena Infrastructure
# 这是一个标准的、最简化的 Athena 配置，包含两个核心组件：
# 1. S3 Bucket: 专门用来存放 Athena 的查询结果 (CSV文件)。
# 2. Athena Workgroup: 一个配置环境，强制所有查询结果都存到上面的 Bucket 里。
# ------------------------------------------------------------------------------

# 1. 查询结果存储桶
# Athena 必须有一个地方存放 "SELECT *" 的结果文件。
# 我们创建一个独立的桶，把它和原始数据桶分开，保持整洁。
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.project_name}-${var.environment}-athena-results-${var.aws_region}"
  force_destroy = true # 开发环境常用：允许 Terraform 销毁非空桶

  tags = {
    Name        = "${var.project_name}-athena-results"
    Environment = var.environment
  }
}

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

# 基础加密配置 (Standard)
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results_encryption" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 阻止所有公共访问 (Security Best Practice)
resource "aws_s3_bucket_public_access_block" "athena_results_block" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Athena Workgroup (工作组)
# 这是管理 Athena 查询环境的最佳方式。
# 它强制了配置 (enforce_workgroup_configuration = true)，
# 这样当你或者队友在控制台切换到这个 Workgroup 时，
# 不需要手动填 S3 路径，直接就能跑查询，不会报错。
resource "aws_athena_workgroup" "etl_workgroup" {
  name = "${var.project_name}_${var.environment}_workgroup"

  configuration {
    # 强制将查询结果存入我们上面创建的桶
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/output/"
      
      encryption_configuration {
        encryption_option = "SSE_S3" # 使用 S3 托管密钥进行加密
      }
    }

    # 关键配置：强制客户端使用这个 Workgroup 的设置
    # 这意味着无论谁用这个 Workgroup，结果都会整齐地去到同一个 S3 路径
    enforce_workgroup_configuration = true
    
    # 发布 CloudWatch 指标，方便监控查询用了多少数据量（省钱用）
    publish_cloudwatch_metrics_enabled = true
  }

  force_destroy = true # 允许删除即使里面有未完成的查询记录
  state         = "ENABLED"

  tags = {
    Environment = var.environment
  }
}
