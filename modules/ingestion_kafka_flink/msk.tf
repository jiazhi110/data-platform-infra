# --- MSK SCRAM 秘密关联 ---
# 将上面创建的 Secrets Manager 秘密与 MSK 集群进行关联。
resource "aws_msk_scram_secret_association" "msk_association" {
  cluster_arn = aws_msk_cluster.kafka_cluster.arn
  secret_arn_list = [
    aws_secretsmanager_secret.msk_scram_credentials.arn
  ]
}

# --- MSK Kafka 集群 ---
# 创建核心的 Kafka 集群。
resource "aws_msk_cluster" "kafka_cluster" {
  cluster_name           = var.msk_cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = length(var.private_subnet_ids) # 每个子网一个 broker，实现高可用,一个 Broker 对应一台 EC2 实例。

  broker_node_group_info {
    instance_type   = var.kafka_broker_instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10 # 单位 GB
      }
    }
  }

  # --- 认证与加密配置 (关键变更) ---
  # 启用客户端认证，并指定使用 SASL/SCRAM。
  client_authentication {
    sasl {
      scram = true
    }
  }

  # 启用 TLS 加密。
  encryption_info {
    # 启用数据“静态加密（encryption at rest）”指定 CMK，改了，改成用encryption_at_rest_kms_key_arn
    # encryption_at_rest {
    #   data_volume_kms_key_id = aws_kms_key.msk_data_cmk.arn
    # }
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_data_cmk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

  # 关联 SCRAM 认证的秘密
  # 注意：aws_msk_scram_secret_association 资源创建后，这里会自动关联，
  # 但显式依赖可以确保创建顺序正确。
  # aws_msk_scram_secret_association 依赖 Secret + Cluster，Terraform 会自动识别，因为它引用了两者的 ARN/ID。如果写了 depends_on = association 就直接触发了循环，导致报错：Error: Cycle
  # depends_on = [aws_msk_scram_secret_association.msk_association]

  # monitor
  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk.name
      }
      s3 {
        enabled = true
        bucket  = aws_s3_bucket.msk_logs_bucket.id
      }
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = true
      }
      node_exporter {
        enabled_in_broker = true
      }
    }
  }

  tags = {
    Name = var.msk_cluster_name
  }
}

# --- MSK Kafka cloudwatch ---
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.msk_cluster_name}"
  retention_in_days = 14
}

# ===================================================================
# S3 Bucket for MSK Broker Logs
# ===================================================================
resource "aws_s3_bucket" "msk_logs_bucket" {
  bucket = "${var.project_name}-msk-logs-${var.environment}-${data.aws_caller_identity.me.account_id}"

  tags = {
    Name = "${var.project_name}-msk-logs-bucket"
  }
}

# 为 MSK Kafka 集群创建一个安全组，用于控制网络访问。
resource "aws_security_group" "msk_sg" {
  name        = var.msk_sg_name
  description = "Allow traffic to MSK brokers"
  vpc_id      = var.vpc_id

  # egress all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.msk_sg_name
  }
}

# create per-client ingress rules (client SGs passed in)
resource "aws_security_group_rule" "ecs_to_msk_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk_sg.id
  source_security_group_id = aws_security_group.ecs_tasks_sg.id
  from_port = 9096 #SASL/SCRAM 常用 9096 (内部)；TLS 用 9094；IAM 用 9098
  to_port   = 9096
  protocol  = "tcp"
}

# kms CMK for data encryption, AES 256 for MSK、S3、EBS、RDS
resource "aws_kms_key" "msk_data_cmk" {
  description = "CMK for MSK data volumes (encryption at rest)"
  policy      = data.aws_iam_policy_document.msk_data_cmk_policy.json

  # 生产常开：true；dev 环境可设 false
  enable_key_rotation = true
  tags = {
    Name = "${var.environment}-msk-data-cmk"
  }
}

# cmk 别名
resource "aws_kms_alias" "msk_data_cmk_alias" {
  name          = "alias/${var.environment}-msk-data-cmk"
  target_key_id = aws_kms_key.msk_data_cmk.key_id
}

# kms CMK for user encryption
resource "aws_kms_key" "msk_secrets_cmk" {
  description = "CMK for MSK SCRAM secrets"
  policy      = data.aws_iam_policy_document.msk_kms_policy.json

  # 生产常开：true；dev 环境可设 false
  enable_key_rotation = true
}

# --- AWS Secrets Manager: 存储 Kafka 用户凭证 ---
# 这是标准的做法：将敏感信息（如密码）存储在 Secrets Manager 中，而不是硬编码在代码里。

# secret key
resource "aws_secretsmanager_secret" "msk_scram_credentials" {
  name        = var.msk_scram_name
  description = "SCRAM credentials for MSK cluster"
  kms_key_id  = aws_kms_key.msk_secrets_cmk.arn
}

# 将传入的用户名密码变量（一个 map）转换为 Secrets Manager 所需的 JSON 字符串格式。
resource "aws_secretsmanager_secret_version" "msk_scram_credentials_version" {
  secret_id = aws_secretsmanager_secret.msk_scram_credentials.id
  secret_string = jsonencode({
    username = var.kafka_scram_user.username
    password = var.kafka_scram_user.password
  })
}

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
      type        = "Service"
      identifiers = ["kafka.amazonaws.com"]
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

