# -----------------------------------------------------------------------------
# 创建实时数据摄取服务所需的核心 AWS 资源。
# -----------------------------------------------------------------------------

# --- AWS Secrets Manager: 存储 Kafka 用户凭证 ---
# 这是标准的做法：将敏感信息（如密码）存储在 Secrets Manager 中，而不是硬编码在代码里。

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

# secret key
resource "aws_secretsmanager_secret" "msk_scram_credentials" {
  name        = var.msk_scram_name
  description = "SCRAM credentials for MSK cluster"
  kms_key_id   = aws_kms_key.msk_secrets_cmk.arn
}

# 将传入的用户名密码变量（一个 map）转换为 Secrets Manager 所需的 JSON 字符串格式。
resource "aws_secretsmanager_secret_version" "msk_scram_credentials_version" {
  secret_id     = aws_secretsmanager_secret.msk_scram_credentials.id
  secret_string = jsonencode(var.kafka_scram_users)
}

# --- MSK SCRAM 秘密关联 ---
# 将上面创建的 Secrets Manager 秘密与 MSK 集群进行关联。
resource "aws_msk_scram_secret_association" "msk_association" {
  cluster_arn = aws_msk_cluster.kafka_cluster.arn
  secret_arn_list = [
    aws_secretsmanager_secret.msk_scram_credentials.arn
  ]
}

# --- 安全组 (Security Group) ---

# 创建 ECS client SG（示例）
resource "aws_security_group" "ecs_tasks_sg" {
  name   = "${var.environment}-ecs-tasks-sg"
  vpc_id = var.vpc_id

  # 允许出站（通常默认允许所有出站；显式写也行）
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-ecs-tasks-sg" }
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
  # for_each = toset(var.client_security_group_ids)
  # source_security_group_id = each.value # for_each 的值，固定写法，如果有变量赋值给for_each,那么，后面就可以用each.value的写法赋值。
  from_port                = 9096 #SASL/SCRAM 常用 9096 (内部)；TLS 用 9094；IAM 用 9098
  to_port                  = 9096
  protocol                 = "tcp"
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
  bucket = var.msk_logs_bucket

  # 添加一个随机后缀，确保桶名在全局唯一
  # 如果不加，当别人也用了这个名字时，你的 apply 可能会失败
  # bucket_prefix = "my-justin-data-platform-logs-" 
  # Conflicting configuration arguments
  # bucket_prefix = var.msk_logs_bucket_prefix

  tags = {
    Name = "${var.project_name}-msk-logs-bucket"
  }
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

# --- ECR (Elastic Container Registry) ---
# 这是存放你 Producer 应用 Docker 镜像的私有仓库。
resource "aws_ecr_repository" "producer_repo" {
  name                 = "${var.project_name}-${var.environment}-producer-repo"
  image_tag_mutability = "MUTABLE" # 允许覆盖标签，方便 dev 环境使用 'latest'

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-producer-repo"
  }
}

# ECS task executed role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

# 附加托管策略（AWS 官方推荐做法）托管策略：基础能力，省事、通用（CloudWatch Logs、ECR、S3 ReadOnly）。
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS task role
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# 为这个角色创建一个内联策略，明确授予读取特定 Secret 的权限
# 专门用来创建并附加 inline policy，只能属于某一个角色
resource "aws_iam_role_policy" "read_kafka_secret_policy" {
  name = "ReadKafkaSecretPolicy"
  role = aws_iam_role.ecs_task_role.id
  policy      = data.aws_iam_policy_document.ecs_task_policy.json
}

# --- ECS (Elastic Container Service) ---
# ECS 集群 - 无需改变
resource "aws_ecs_cluster" "main_cluster" {
  name = "${var.project_name}-${var.environment}-cluster"
}

# CloudWatch 日志组 - 更新名称以适配 Flink
resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.flink_task_family}"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "producer_task" {
  family                   = var.flink_task_family
  #对 Fargate 来说 必须，因为 Fargate 不允许使用 bridge 或 host 模式
  # 对 EC2 launch type 可以用其他模式，但 Fargate 只能 awsvpc
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  # cpu                      = "256"  # 0.25 vCPU
  # memory                   = "512"  # 512 MB
  cpu                      = var.flink_task_cpu
  memory                   = var.flink_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # 容器定义
  container_definitions = jsonencode([
    # --- Job Manager 容器 ---
    {
      name      = "jobmanager",
      image     = var.flink_image_uri,
      # image     = data.aws_ecr_image.flink_image.image_uri,  # 这里用动态URI，这里用client payload 的 output parameter.
      essential = true, # 如果这个容器失败，整个 Task 会失败  essential：必要的
      #Flink 官方镜像里 JobManager/TaskManager 脚本 /opt/flink/bin/jobmanager.sh 或 taskmanager.sh 默认需要一个参数 start-foreground 才会以前台方式启动  start-foreground :启动前台
      command   = ["start-foreground"],
      entryPoint = [
        "/opt/flink/bin/jobmanager.sh"
      ],
      environment = [
        { name = "FLINK_PROPERTIES_jobmanager.rpc.address", value = "jobmanager" }
        # 在这里可以添加更多 Flink 配置作为环境变量
      ],
      portMappings = [
        { containerPort = 8081, hostPort = 8081, protocol = "tcp" }, # Web UI
        { containerPort = 6123, hostPort = 6123, protocol = "tcp" }  # RPC Port
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "jobmanager" # 使用容器名作为流前缀，方便区分日志
        }
      }
    },
    # --- Task Manager 容器 ---
    {
      name      = "taskmanager",
      # image     = var.flink_image_uri,
      image     = var.flink_image_uri,  # 这里用ingestion_kafka_flink 的 flink_image_uri.
      essential = true, # 在 dev 环境，建议也设为 true，确保集群的完整性
      command   = ["start-foreground"],
      entryPoint = [
        "/opt/flink/bin/taskmanager.sh"
      ],
      # 容器间可以通过 localhost 通信，但为了清晰，我们明确指向 jobmanager
      dependsOn = [
        { containerName = "jobmanager", condition = "START" }
      ],
      environment = [
        { name = "FLINK_PROPERTIES_jobmanager.rpc.address", value = "jobmanager" },
        { name = "FLINK_PROPERTIES_taskmanager.numberOfTaskSlots", value = "2" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "taskmanager"
        }
      }
    }
  ])
}

# CloudWatch 日志组，用于收集容器日志
resource "aws_cloudwatch_log_group" "producer_logs" {
  name              = "/ecs/${var.project_name}-producer"
  retention_in_days = 14
}

# ECS 服务 (Service): 运行并维护“蓝图”的实例
# 确保始终有指定数量的任务在运行，并负责网络配置
resource "aws_ecs_service" "producer_service" {
  name            = "${var.project_name}-${var.environment}-producer-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.producer_task.arn
  desired_count   = 1 # 我们希望始终运行 1 个 producer 任务
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false # 我们的 producer 在私有网络中运行，更安全
  }

  # 确保在任务定义更新后，服务能自动部署新版本
  force_new_deployment = true
}