# 自带的，但是还是得声明。account_id   # 当前账户 ID，arn          # 当前调用者 ARN，user_id      # 当前调用者唯一 ID
data "aws_caller_identity" "me" {}



# 只跑 CD + latest：环境的变化由“外部 push 镜像 + 随机 Terraform apply”触发，失去控制。
# CI/CD 全套：构建 → 推送 → Terraform 更新，整个链条可控、可追溯。
# 最终方案，用ingestion_kafka_flink 的 image_url 来直接代替。

# data "aws_ecr_image" "flink_image" {
#   repository_name = aws_ecr_repository.producer_repo.name
#   image_tag       = "latest"  # 或用 most_recent = true（如果你的镜像有多个tag，它会取最新的）
#   depends_on      = [aws_ecr_repository.producer_repo]  # 确保仓库先创建
#   most_recent     = true  # 加这个，确保按时间取最新
# }


