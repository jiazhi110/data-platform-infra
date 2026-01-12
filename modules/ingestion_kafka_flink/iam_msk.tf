# --- MSK Kafka Cluster ---
resource "aws_msk_cluster" "kafka_cluster" {
  cluster_name           = "${var.project_name}-${var.environment}-msk-cluster"
  kafka_version          = var.kafka_version
  # High availability: one broker per subnet (one broker per EC2 instance).
  number_of_broker_nodes = length(var.private_subnet_ids) 

  broker_node_group_info {
    instance_type   = var.kafka_broker_instance_type
    client_subnets  = var.private_subnet_ids
    security_groups = [aws_security_group.msk_sg.id]

    storage_info {
      ebs_storage_info {
        volume_size = 10 # GB
      }
    }

    # Note: For VPC-internal clients (ECS, Lambda), auth must be defined in vpc_connectivity.
    # Top-level client_authentication is typically for public or legacy configurations.
    # Enables IAM auth for VPC clients.
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

  # Enable client authentication via SASL/IAM.
  client_authentication {
    sasl {
      iam = true
    }
  }

  # # ⚠️ Dev/Test only: Enable MSK public access. Use private connectivity in production.
  # connectivity_info {
  #   public_access {
  #     type = "SERVICE_PROVIDED_EIPS"
  #   }
  # }

  # Enable TLS encryption in transit and at rest.
  encryption_info {
    encryption_at_rest_kms_key_arn = aws_kms_key.msk_data_cmk.arn
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
  }

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
resource "aws_s3_bucket_public_access_block" "msk_logs_block" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable default SSE-S3 encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "msk_logs_encryption" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Lifecycle: Expire logs after 90 days to balance audit needs and costs.
resource "aws_s3_bucket_lifecycle_configuration" "msk_logs_lifecycle" {
  bucket = aws_s3_bucket.msk_logs_bucket.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90 
    }
  }
}

# MSK Service Linked Role (Enable only if it doesn't exist in the account).
# resource "aws_iam_service_linked_role" "msk" {
#   aws_service_name = "kafka.amazonaws.com"
# }

# MSK Cluster Security Group
resource "aws_security_group" "msk_sg" {
  name        = "${var.project_name}-${var.environment}-msk-sg"
  description = "Allow traffic to MSK brokers"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # # ⚠️ Dev/Test only: Allow public access to MSK brokers.
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

# Ingress for Flink ECS tasks (IAM Auth uses port 9098).
resource "aws_security_group_rule" "ecs_to_msk_ingress" {
  type                     = "ingress"
  security_group_id        = aws_security_group.msk_sg.id
  source_security_group_id = aws_security_group.ecs_tasks_sg.id
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  description              = "Allow Flink ECS Task to connect to MSK Broker (IAM Auth)"
}

# KMS CMK for data encryption at rest.
resource "aws_kms_key" "msk_data_cmk" {
  description = "CMK for MSK data volumes (encryption at rest)"
  policy      = data.aws_iam_policy_document.msk_data_cmk_policy.json

  enable_key_rotation = true
  tags = {
    Name = "${var.environment}-msk-data-cmk"
  }
}

resource "aws_kms_alias" "msk_data_cmk_alias" {
  name          = "alias/${var.environment}-msk-data-cmk"
  target_key_id = aws_kms_key.msk_data_cmk.key_id
}

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

  # Allow MSK service-linked role to use the key.
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

# Runner Security Group for management access.
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
# Grants necessary IAM roles permissions to perform Kafka actions via IAM auth.
resource "aws_msk_cluster_policy" "main" {
  cluster_arn = aws_msk_cluster.kafka_cluster.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = [
            aws_iam_role.ecs_task_role.arn,
            aws_iam_role.mock_data_task_role.arn,
            data.aws_caller_identity.me.arn
          ]
        },
        Action = [
          "kafka-cluster:Connect",
          "kafka-cluster:DescribeCluster",
          "kafka-cluster:AlterCluster",
          "kafka-cluster:ReadData",
          "kafka-cluster:WriteData",
          "kafka-cluster:DescribeGroup",
          "kafka-cluster:AlterGroup",
          "kafka-cluster:DescribeTopic",
          "kafka-cluster:CreateTopic",
          "kafka-cluster:AlterTopic",
          "kafka-cluster:DeleteTopic"
        ],
        Resource = aws_msk_cluster.kafka_cluster.arn
      }
    ]
  })
}

# --- ACL for Mock Data Generator ---
resource "kafka_acl" "mock_data_producer_acl" {
  acl_principal                = "User:${aws_iam_role.mock_data_task_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Write"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"
}

# --- ACLs for Flink Consumer ---
resource "kafka_acl" "flink_consumer_acl" {
  acl_principal                = "User:${aws_iam_role.ecs_task_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"
}

resource "kafka_acl" "flink_consumer_group_acl" {
  acl_principal                = "User:${aws_iam_role.ecs_task_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Group"
  resource_name                = "*" 
  resource_pattern_type_filter = "Literal"
}

# --- ACLs for Management Runner ---
data "aws_iam_role" "ec2_runner_role" {
  name = var.runner_iam_role_name
}

resource "kafka_acl" "ec2_runner_consumer_acl" {
  acl_principal                = "User:${data.aws_iam_role.ec2_runner_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Topic"
  resource_name                = kafka_topic.produce_events.name
  resource_pattern_type_filter = "Literal"
}

resource "kafka_acl" "ec2_runner_consumer_group_acl" {
  acl_principal                = "User:${data.aws_iam_role.ec2_runner_role.arn}"
  acl_host                     = "*"
  acl_operation                = "Read"
  acl_permission_type          = "Allow"
  resource_type                = "Group"
  resource_name                = "*" 
  resource_pattern_type_filter = "Literal"
}

# ------------------------------------------------------------------------------
# MSK Storage Auto Scaling
# ------------------------------------------------------------------------------
# Automatically increases EBS volume size when storage utilization reaches threshold.
resource "aws_appautoscaling_target" "msk_storage_target" {
  service_namespace  = "kafka"
  resource_id        = aws_msk_cluster.kafka_cluster.arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  # Note: Minimum capacity must be 1 for MSK scaling.
  min_capacity       = 1
  max_capacity       = 1000
}

resource "aws_appautoscaling_policy" "msk_storage_policy" {
  name               = "${var.project_name}-${var.environment}-msk-storage-scaling"
  service_namespace  = aws_appautoscaling_target.msk_storage_target.service_namespace
  resource_id        = aws_appautoscaling_target.msk_storage_target.resource_id
  scalable_dimension = aws_appautoscaling_target.msk_storage_target.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }
    target_value = 70.0
  }
}
