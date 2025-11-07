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

  # --- 认证与加密配置 (IAM) ---
  # 启用客户端认证，并指定使用 SASL/IAM。
  client_authentication {
    sasl {
      iam = true
    }
  }

  # # ⚠️ 仅用于开发/测试环境：启用 MSK 公网访问
  # # 在生产环境中，请勿启用此配置，应使用私有网络连接
  # connectivity_info {
  #   public_access {
  #     type = "SERVICE_PROVIDED_EIPS"
  #   }
  # }

  # 启用 TLS 加密。
  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_data_cmk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

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
  force_destroy = true

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

  # # ⚠️ 仅用于开发/测试环境：允许公网访问 MSK
  # # 在生产环境中，请勿启用此规则，应使用私有网络连接（如 VPN 或自托管 Runner）
  # ingress {
  #   from_port   = 9098
  #   to_port     = 9098
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = var.msk_sg_name
  }
}

# create per-client ingress rules (client SGs passed in)
resource "aws_security_group_rule" "ecs_to_msk_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk_sg.id
  source_security_group_id = aws_security_group.ecs_tasks_sg.id
  from_port = 9098 #SASL/SCRAM 常用 9096 (内部)；TLS 用 9094；IAM 用 9098
  to_port   = 9098
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

# --- Runner Security Group --- 
data "aws_security_group" "runner_sg" {
  name = var.runner_security_group_name
}

resource "aws_security_group_rule" "runner_to_msk_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk_sg.id
  source_security_group_id = data.aws_security_group.runner_sg.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  description              = "Allow Ingress from GitHub Actions Runner"
}

# --- SSM Parameters for MSK Bootstrap Brokers ---
resource "aws_ssm_parameter" "msk_bootstrap_brokers_public" {
  name  = "/${var.project_name}/${var.environment}/kafka/bootstrap_brokers_public"
  type  = "String"
  value = aws_msk_cluster.kafka_cluster.bootstrap_brokers_public_sasl_iam
  overwrite = true
}

resource "aws_ssm_parameter" "msk_bootstrap_brokers_private" {
  name  = "/${var.project_name}/${var.environment}/kafka/bootstrap_brokers_private"
  type  = "String"
  value = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
  overwrite = true
}
