# 1. Glue Service Role
#    允许 Glue 服务扮演这个角色来操作 AWS 资源
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

# 2. 附加 AWS 托管的 Glue 基础策略
#    这个策略包含了 CloudWatch Logs 写日志、Glue API 调用等基础权限，省得我们自己写
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# 3. 自定义策略：只控制 S3 访问
#    这是我们需要手动控制的部分，特别是对数据桶的读写
resource "aws_iam_role_policy" "glue_s3_access" {
  name = "GlueS3Access"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 权限 A: 读写脚本和临时文件
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
          "arn:aws:s3:::${var.source_s3_bucket_name}",
          "arn:aws:s3:::${var.source_s3_bucket_name}/*"
        ]
      },
      # 权限 B: 读写数据湖 (Flink输出 + ETL输出)
      {
        Sid    = "AccessDataLake"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject" # 如果 Glue 需要写回结果到数据桶
        ]
        resources = [
          "arn:aws:s3:::${var.destination_s3_bucket_name}",
          "arn:aws:s3:::${var.destination_s3_bucket_name}/*"
        ]
      }
    ]
  })
}