# 1. Glue Service Role
#    允许 Glue 服务扮演这个角色来操作 AWS 资源
# document user guide ： https://docs.aws.amazon.com/zh_cn/glue/latest/dg/attach-policy-iam-user.html https://docs.aws.amazon.com/zh_cn/glue/latest/dg/set-up-iam.html
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
      # 权限 A: 读写脚本、临时文件和assets桶
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
      # 权限 B: 读写数据湖 (Flink输出 + ETL输出)
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

# 管理员Policy：允许Terraform调用者管理Glue资源和传递角色 这个东西后面整，因为这个是 全局 执行terraform role policy，后面跑的时候一起给。现在是 administrator access.
# resource "aws_iam_policy" "glue_admin_policy" {
#   name        = "${var.project_name}-${var.environment}-glue-admin-policy"
#   description = "允许管理Glue Job、Crawler和传递执行角色"

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       # 允许Glue管理API（创建/更新Job和Crawler）
#       {
#         Sid    = "GlueManagement"
#         Effect = "Allow"
#         Action = [
#           "glue:CreateJob",
#           "glue:DeleteJob",
#           "glue:GetJob",
#           "glue:GetJobs",
#           "glue:UpdateJob",
#           "glue:StartJobRun",
#           "glue:StopJobRun",
#           "glue:CreateCrawler",
#           "glue:DeleteCrawler",
#           "glue:GetCrawler",
#           "glue:GetCrawlers",
#           "glue:UpdateCrawler",
#           "glue:StartCrawler",
#           "glue:StopCrawler",
#           "glue:GetCrawlerMetrics",
#           "glue:CreateDatabase",
#           "glue:DeleteDatabase",
#           "glue:GetDatabase",
#           "glue:GetDatabases"
#         ]
#         Resource = [
#           "*",
#           "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.me.account_id}:job/${var.project_name}-${var.environment}-top-produce-etl",
#           "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.me.account_id}:crawler/${var.project_name}-${var.environment}-crawler",
#           "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.me.account_id}:database/${var.project_name}_${var.environment}_db"
#         ]
#       },
#       # 允许传递Glue执行角色给Glue服务
#       {
#         Sid    = "PassGlueRole"
#         Effect = "Allow"
#         Action = "iam:PassRole"
#         Resource = aws_iam_role.glue_job_role.arn
#       }
#     ]
#   })
# }

# # 附加Policy到你的管理员角色（替换your_admin_role_name为实际名）
# resource "aws_iam_role_policy_attachment" "glue_admin_attachment" {
#   role       = aws_iam_role.glue_job_role.name
#   policy_arn = aws_iam_policy.glue_admin_policy.arn
# }