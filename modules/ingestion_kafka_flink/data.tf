# 自带的，但是还是得声明。account_id   # 当前账户 ID，arn          # 当前调用者 ARN，user_id      # 当前调用者唯一 ID
data "aws_caller_identity" "me" {}

# permission policy
data "aws_iam_policy_document" "msk_kms_policy" {
  # 允许 root/admin 管理 key
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.me.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # 允许 Secrets Manager 用 key
  statement {
    sid = "AllowSecretsManagerUseOfTheKey"
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
  }

  # 允许 MSK 用 key
  statement {
    sid = "AllowMSKUseOfTheKey"
    principals {
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
    }
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]
  }
}


# 可选：把这个 permission policy 用 data.aws_iam_policy_document 更优雅地生成
data "aws_iam_policy_document" "msk_data_cmk_policy" {
  statement {
    sid    = "AllowAccountAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.me.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = ["*"]
  }

  # 允许 MSK service-linked role 使用 key (必要)
  statement {
    sid    = "AllowMSKServiceRoleUse"
    effect = "Allow"
    principals {
      type        = "AWS"
      # 服务关联角色路径（推荐使用 service-linked role ARN）
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.me.account_id}:role/aws-service-role/kafka.amazonaws.com/AWSServiceRoleForKafka"
      ]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

# 1. ECS 任务执行角色 (Task Execution Role)  trust policy
# 这个角色授予 ECS Agent 权限，让它能帮你做事，比如：
# - 从 ECR 拉取你的 Docker 镜像
# - 将应用的日志发送到 CloudWatch
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# 生成 AssumeRole Policy ECS Task Role    信任策略（Trust Policy）
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# 最小权限策略                            权限策略（Permission Policy）
data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    sid    = "ReadKafkaSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [aws_secretsmanager_secret.msk_scram_credentials.arn]
  }

  statement {
    sid    = "KafkaClusterAccess"
    effect = "Allow"
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers",
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData",
      "kafka-cluster:WriteData",
      "kafka-cluster:DescribeGroup"
    ]
    # resources = ["*"] # 建议限定到你创建的 MSK Cluster ARN
    resources = [aws_msk_cluster.kafka_cluster.arn]
  }

  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.flink_output_bucket}",
      "arn:aws:s3:::${var.flink_output_bucket}/*"
    ]
  }
}

# 只跑 CD + latest：环境的变化由“外部 push 镜像 + 随机 Terraform apply”触发，失去控制。
# CI/CD 全套：构建 → 推送 → Terraform 更新，整个链条可控、可追溯。
# 最终方案，用ingestion_kafka_flink 的 image_url 来直接代替。

# data "aws_ecr_image" "flink_image" {
#   repository_name = aws_ecr_repository.producer_repo.name
#   image_tag       = "latest"  # 或用 most_recent = true（如果你的镜像有多个tag，它会取最新的）
#   depends_on      = [aws_ecr_repository.producer_repo]  # 确保仓库先创建
#   most_recent     = true  # 加这个，确保按时间取最新
# }


