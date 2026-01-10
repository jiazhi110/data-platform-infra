# --- MSK Kafka Cluster ---
# Create the core Kafka cluster.
# 创建核心的 Kafka 集群。
resource "aws_msk_cluster" "kafka_cluster" {
  cluster_name           = "${var.project_name}-${var.environment}-msk-cluster"
  kafka_version          = var.kafka_version
  # One broker per subnet for high availability. One broker corresponds to one EC2 instance.
  # 每个子网一个 broker，实现高可用,一个 Broker 对应一台 EC2 实例。
  number_of_broker_nodes = length(var.private_subnet_ids) 

  broker_node_group_info {
    instance_type   = var.kafka_broker_instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10 # Unit: GB
      }
    }

    # [Note] Key configuration for MSK client authentication
    # [注释] MSK 客户端认证的关键配置
    # -----------------------------------------------------------------
    # For clients running inside the VPC (e.g., ECS tasks, Lambda), authentication methods must be defined in the `vpc_connectivity` block.
    # The top-level `client_authentication` block only applies to clients with public access or as legacy config; it doesn't work for pure intranet clusters.
    # Configuring IAM authentication here ensures that VPC internal clients can successfully authenticate via IAM roles. Note: only applicable to t5 large.
    # 对于在 VPC 内部运行的客户端（例如 ECS 任务、Lambda），必须在此处的 `vpc_connectivity` 块中定义认证方法。
    # 顶层的 `client_authentication` 块仅适用于公网访问的客户端或作为遗留配置，对于纯内网访问的集群不起作用。
    # 将 IAM 认证配置在这里，可以确保 VPC 内部的客户端能够成功通过 IAM 角色进行认证。  但是它仅仅只适用于 t5 large
    # connectivity_info {
    #   vpc_connectivity {
    #     client_authentication {
    #       sasl {
    #         iam = true
    #       }
    #     }
    #   }
    # }
  }

  # --- Authentication and Encryption Config (IAM) ---
  # Enable client authentication and specify SASL/IAM.
  # --- 认证与加密配置 (IAM) ---
  # 启用客户端认证，并指定使用 SASL/IAM。
  # aws kafka describe-cluster, the ClientAuthentication blow is invalid
  client_authentication {
    sasl {
      iam = true
    }
  }

  # # ⚠️ Dev/Test only: Enable MSK public access
  # # ⚠️ 仅用于开发/测试环境：启用 MSK 公网访问
  # # In production, do not enable this; use private network connections instead.
  # # 在生产环境中，请勿启用此配置，应使用私有网络连接
  # connectivity_info {
  #   public_access {
  #     type = "SERVICE_PROVIDED_EIPS"
  #   }
  # }

  # Enable TLS encryption.
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
    Name = "${var.project_name}-${var.environment}-msk-cluster"
  }
}

# --- MSK Kafka cloudwatch ---
resource "aws_cloudwatch_log_group" "msk" {
  name              = "/aws/msk/${var.project_name}-${var.environment}-msk-cluster"
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

# Security Best Practice: Block public access to S3
# [新增] 阻止公网访问 (Block Public Access)
resource "aws_s3_bucket_public_access_block" "msk_logs_block" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable default server-side encryption to protect static data.
# [新增] 服务端加密 (Server-Side Encryption)
resource "aws_s3_bucket_server_side_encryption_configuration" "msk_logs_encryption" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Lifecycle Management - Expire logs after 90 days.
# [新增] MSK 日志桶生命周期管理
resource "aws_s3_bucket_lifecycle_configuration" "msk_logs_lifecycle" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      # Retain logs for 90 days to balance auditing needs and costs.
      days = 90 # 保留 90 天日志，兼顾审计需求与成本
    }
  }
}

# [Memo] MSK Service Linked Role
# [备忘] MSK 服务关联角色
# Only needed for new accounts that haven't manually created a Kafka cluster.
# Otherwise, it will error with "Role already exists".
# 仅在新账号且从未手动创建过 Kafka 集群时需要启用。
# 否则会报错 "Role already exists"。
# resource "aws_iam_service_linked_role" "msk" {
#   aws_service_name = "kafka.amazonaws.com"
# }

# Create a security group for MSK Kafka cluster to control network access.
# 为 MSK Kafka 集群创建一个安全组，用于控制网络访问。
resource "aws_security_group" "msk_sg" {
  name        = "${var.project_name}-${var.environment}-msk-sg"
  description = "Allow traffic to MSK brokers"
  vpc_id      = var.vpc_id

  # egress all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # # ⚠️ Dev/Test only: Allow public access to MSK
  # # In production, do not enable this rule; use private connections (e.g., VPN or self-hosted Runner).
  # # ⚠️ 仅用于开发/测试环境：允许公网访问 MSK
  # # 在生产环境中，请勿启用此规则，应使用私有网络连接（如 VPN 或自托管 Runner）
  # ingress {
  #   from_port   = 9098
  #   to_port     = 9098
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = "${var.project_name}-${var.environment}-msk-sg"
  }
}


# create per-client ingress rules (client SGs passed in)
resource "aws_security_group_rule" "ecs_to_msk_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk_sg.id
  source_security_group_id = aws_security_group.ecs_tasks_sg.id
  # SASL/SCRAM uses 9096 (internal); TLS uses 9094; IAM uses 9098.
  from_port                = 9098 #SASL/SCRAM 常用 9096 (内部)；TLS 用 9094；IAM 用 9098
  to_port                  = 9098
  protocol                 = "tcp"
  description              = "Allow Flink ECS Task to connect to MSK Broker (IAM Auth)"
}

# kms CMK for data encryption, AES 256 for MSK、S3、EBS、RDS
resource "aws_kms_key" "msk_data_cmk" {
  description = "CMK for MSK data volumes (encryption at rest)"
  policy      = data.aws_iam_policy_document.msk_data_cmk_policy.json

  # Production always on (true); dev environment can set to false.
  # 生产常开：true；dev 环境可设 false
  enable_key_rotation = true
  tags = {
    Name = "${var.environment}-msk-data-cmk"
  }
}

# cmk alias
# cmk 别名
resource "aws_kms_alias" "msk_data_cmk_alias" {
  name          = "alias/${var.environment}-msk-data-cmk"
  target_key_id = aws_kms_key.msk_data_cmk.key_id
}

# Optional: Generate this permission policy more elegantly using data.aws_iam_policy_document.
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

  # Allow MSK service-linked role to use the key (Necessary)
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

resource "aws_ssm_parameter" "msk_bootstrap_brokers_private" {
  name  = "/${var.project_name}/${var.environment}/kafka/bootstrap_brokers_private"
  type  = "String"
  value = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
  overwrite = true
}

# --- MSK Cluster Policy ---
# This policy grants specific IAM roles the necessary permissions to connect to the MSK cluster
# and perform Kafka actions. Without this, all IAM-based connection attempts will be denied.

resource "aws_msk_cluster_policy" "main" {
  cluster_arn = aws_msk_cluster.kafka_cluster.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [
            # 1. Grant access to the Flink task role
            aws_iam_role.ecs_task_role.arn,

            # 2. Grant access to the Mock Data Generator task role
            aws_iam_role.mock_data_task_role.arn,

            # 3. Grant access to the role running Terraform (e.g., the GitHub Actions runner)
            # This is needed for the kafka_topic and kafka_acl resources.
            data.aws_caller_identity.me.arn
          ]
        },
        Action = [
          "kafka-cluster:Connect",         # Required for clients to connect
          "kafka-cluster:DescribeCluster", # View cluster details
          "kafka-cluster:AlterCluster",    # Modify cluster (e.g., for Terraform management)
          "kafka-cluster:ReadData",        # Consume from topics
          "kafka-cluster:WriteData",       # Produce to topics
          "kafka-cluster:DescribeGroup",   # View consumer groups
          "kafka-cluster:AlterGroup",      # Modify consumer groups
          "kafka-cluster:DescribeTopic",   # View topics
          "kafka-cluster:CreateTopic",     # Create new topics (if needed; remove if not)
          "kafka-cluster:AlterTopic",      # Modify topics
          "kafka-cluster:DeleteTopic"      # Delete topics (if needed; remove if not)
        ],
        # Temporarily allow all operations for debugging.
        # Action   = "kafka-cluster:*", # 暂时允许所有操作，用于调试
        Resource = aws_msk_cluster.kafka_cluster.arn
      }
    ]
  })
}

# --- ACL for Mock Data Generator ---
# Grant Write permission to the mock-data-generator task role, allowing it to produce messages
# to the 'ingestion.user.behavior.v1' topic.
resource "kafka_acl" "mock_data_producer_acl" {
  # Specifically grant write permissions to the mock data generator task role.
  acl_principal                = "User:${aws_iam_role.mock_data_task_role.arn}" # 精确授予 mock data generator 任务角色写入权限
  acl_host                     = "*"
  acl_operation                = "Write"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# --- ACLs for Flink Consumer ---
# Grant Read permission on the topic to the Flink task role.
resource "kafka_acl" "flink_consumer_acl" {
  acl_principal                = "User:${aws_iam_role.ecs_task_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Grant Read permission on Consumer Groups to the Flink task role.
# This is necessary for Flink to manage its consumer offset.
resource "kafka_acl" "flink_consumer_group_acl" {
  acl_principal                = "User:${aws_iam_role.ecs_task_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Group"
  # Flink will create a consumer group, so we allow access to any group.
  resource_name                = "*" # Flink will create a consumer group, so we allow access to any group.
  resource_pattern_type_filter = "Literal"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# --- ACLs for EC2 Runner (for manual consumption) ---

# Find the IAM role for the EC2 runner
data "aws_iam_role" "ec2_runner_role" {
  name = var.runner_iam_role_name
}

# Grant Read permission on the topic to the EC2 runner role.
resource "kafka_acl" "ec2_runner_consumer_acl" {
  acl_principal                = "User:${data.aws_iam_role.ec2_runner_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Grant Read permission on Consumer Groups to the EC2 runner role.
resource "kafka_acl" "ec2_runner_consumer_group_acl" {
  acl_principal                = "User:${data.aws_iam_role.ec2_runner_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Group"
  # Allow it to join any consumer group.
  resource_name                = "*" # 允许它加入任何消费者组
  resource_pattern_type_filter = "Literal"

  # lifecycle {
  #   prevent_destroy = true
  # }
}

# ------------------------------------------------------------------------------
# MSK Storage Auto Scaling
# MSK 存储自动扩容 (Storage Auto Scaling)
# ------------------------------------------------------------------------------
# Automatically increases EBS volume size when Kafka Broker disk usage is high.
# 核心功能：当 Kafka Broker 磁盘使用率过高时，自动增加其 EBS 卷大小。
resource "aws_appautoscaling_target" "msk_storage_target" {
  # Namespace for scaling services (kafka).
  # 扩容服务的命名空间，MSK 对应的是 kafka
  service_namespace  = "kafka"
  # Resource identifier (MSK cluster ARN).
  # 具体的资源标识符，这里是 MSK 集群的 ARN
  resource_id        = aws_msk_cluster.kafka_cluster.arn
  # Dimension to scale: Kafka Broker storage volume size.
  # 定义要扩容的维度：Kafka Broker 的存储卷大小
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  # Minimum capacity (GB). Note: Must be 1 for MSK per AWS API requirements.
  # 自动扩容允许的最小值 (GB)  ValidationException: Minimum capacity cannot be greater than 1 ： AWS MSK 自动扩容的一个特殊机制：它只升不降。
  min_capacity       = 1
  # Maximum allowed capacity (GB).
  # 自动扩容允许的最大值 (GB)
  max_capacity       = 1000
}

resource "aws_appautoscaling_policy" "msk_storage_policy" {
  # Policy Name
  # 策略名称
  name               = "${var.project_name}-${var.environment}-msk-storage-scaling"
  # Must match target namespace
  # 必须与 target 中的命名空间一致
  service_namespace  = aws_appautoscaling_target.msk_storage_target.service_namespace
  # Associated resource ID
  # 关联的资源 ID
  resource_id        = aws_appautoscaling_target.msk_storage_target.resource_id
  # Associated scaling dimension
  # 关联的扩容维度
  scalable_dimension = aws_appautoscaling_target.msk_storage_target.scalable_dimension
  # Policy type: Target tracking scaling to maintain metrics near a set value.
  # 策略类型：目标跟踪扩容，使指标维持在设定值附近
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    # Use MSK predefined disk utilization metric.
    # 使用 MSK 预定义的磁盘利用率指标
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }
    # Scaling threshold: perform expansion when disk usage reaches 70%.
    # 触发扩容的阈值：当磁盘使用率达到 70% 时执行扩容
    target_value = 70.0
  }
}