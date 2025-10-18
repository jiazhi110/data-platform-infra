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
    instance_type          = var.kafka_broker_instance_type
    client_subnets         = var.private_subnet_ids
    security_groups        = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10   # 单位 GB
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
        enabled = true
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
