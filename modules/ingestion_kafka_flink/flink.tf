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

# --- ECS (Elastic Container Service) ---
# ECS 集群 - 无需改变
resource "aws_ecs_cluster" "main_cluster" {
  name = "${var.project_name}-${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "producer_task" {
  family = var.flink_task_family
  #对 Fargate 来说 必须，因为 Fargate 不允许使用 bridge 或 host 模式
  # 对 EC2 launch type 可以用其他模式，但 Fargate 只能 awsvpc
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  # cpu                      = "256"  # 0.25 vCPU
  # memory                   = "512"  # 512 MB
  cpu                = var.flink_task_cpu
  memory             = var.flink_task_memory
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # 容器定义
  container_definitions = jsonencode([
    # --- Job Manager 容器 ---
    {
      name  = "jobmanager",
      image = var.flink_image_url,
      # image     = data.aws_ecr_image.flink_image.image_uri,  # 这里用动态URI，这里用client payload 的 output parameter.
      essential = true, # 如果这个容器失败，整个 Task 会失败  essential：必要的
      #Flink 官方镜像里 JobManager/TaskManager 脚本 /opt/flink/bin/jobmanager.sh 或 taskmanager.sh 默认需要一个参数 start-foreground 才会以前台方式启动  start-foreground :启动前台
      command = ["start-foreground"],
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
      linuxParameters = {
        initProcessEnabled = true # 用于配置容器的 Linux 特性，确保一些特定的进程管理功能（如 init 进程）正常工作。
      },
      executeCommandConfiguration = {
        enabled = true # 启用在容器内执行命令的功能，允许你通过 aws ecs execute-command 在容器中执行交互式命令进行调试和管理。
      },
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
      name = "taskmanager",
      # image     = var.flink_image_uri,
      image     = var.flink_image_url, # 这里用ingestion_kafka_flink 的 flink_image_uri.
      essential = true,                # 在 dev 环境，建议也设为 true，确保集群的完整性
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
      executeCommandConfiguration = {
        enabled = true
      },
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

# ECS 服务 (Service): 运行并维护“蓝图”的实例
# 确保始终有指定数量的任务在运行，并负责网络配置
resource "aws_ecs_service" "producer_service" {
  name            = "${var.project_name}-${var.environment}-producer-service"
  cluster         = aws_ecs_cluster.main_cluster.id
  task_definition = aws_ecs_task_definition.producer_task.arn
  desired_count   = 1 # 我们希望始终运行 1 个 producer 任务
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    # Reason for change: Directly exposing Flink UI via public IP for development/debugging.
    # Original: subnets          = var.private_subnet_ids
    # Original: assign_public_ip = false
    subnets          = var.public_subnet_ids # 改为使用公共子网
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true # 启用公网 IP 分配
  }

  # 确保在任务定义更新后，服务能自动部署新版本
  force_new_deployment = true

  # Reason for commenting out: The ALB is disabled, so the service cannot be attached to it.
  # load_balancer {
  #   target_group_arn = aws_lb_target_group.flink_ui_tg.arn
  #   container_name   = "jobmanager" # 必须与容器定义中的 Flink JobManager 容器名称完全匹配
  #   container_port   = 8081
  # }
}

# 在销毁时，先将 ECS 服务的期望任务数降为 0
resource "null_resource" "stop_producer_service" {
  depends_on = [aws_ecs_service.producer_service]

  # Use triggers to pass data to the provisioner, avoiding direct references
  # in the destroy-time provisioner command.
  triggers = {
    cluster_name = aws_ecs_service.producer_service.cluster
    service_name = aws_ecs_service.producer_service.name
    aws_region   = var.aws_region
  }

  # This provisioner runs when the resource is destroyed.
  provisioner "local-exec" {
    when = destroy
    # Reference the triggers via 'self' to comply with destroy-time provisioner rules.
    command = "aws ecs update-service --cluster ${self.triggers.cluster_name} --service ${self.triggers.service_name} --desired-count 0 --region ${self.triggers.aws_region}"
  }
}

# CloudWatch 日志组 - 更新名称以适配 Flink
resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.flink_task_family}"
  retention_in_days = 14
}

# --- Security Group for ALB ---
# Reason for commenting out: The current AWS account does not support creating Load Balancers.
# This section is disabled until the account permissions are resolved.
# resource "aws_security_group" "alb_sg" {
#   name        = "${var.project_name}-${var.environment}-alb-sg"
#   description = "Security group for the Flink UI ALB"
#   vpc_id      = var.vpc_id
# 
#   # 允许所有公网流量访问 HTTP 80 端口
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# 
#   # 允许所有出站流量
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# 
#   tags = {
#     Name = "${var.project_name}-${var.environment}-alb-sg"
#   }
# }

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

  # Temporarily commenting out to break dependency before destroying the ALB security group.
  # ingress {
  #   description     = "Allow traffic from ALB to Flink UI"
  #   from_port       = 8081
  #   to_port         = 8081
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb_sg.id] # 只允许来自我们新创建的 ALB 安全组的流量
  # }

  tags = { Name = "${var.environment}-ecs-tasks-sg" }

  # Reason for adding: To allow public access to the Flink UI on port 8081.
  # WARNING: This exposes the Flink UI to the entire internet. Use with caution, especially in non-development environments.
  ingress {
    description = "Allow public access to Flink UI"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 允许任何 IP 访问
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
  name   = "ReadKafkaSecretPolicy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
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
  # 该声明授予 Flink 任务访问 Kafka 集群的权限
  statement {
    sid    = "KafkaClusterAccess"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeCluster",    # 允许 Flink 客户端发现集群信息
      "kafka-cluster:Connect",            # 允许 Flink 客户端连接到 Kafka Broker
      "kafka-cluster:DescribeTopic",      # 允许 Flink 客户端获取 Topic 的元数据（如分区信息）
      "kafka-cluster:ReadData",           # 允许 Flink 从 Topic 消费数据
      "kafka-cluster:DescribeGroup",      # 允许 Flink 描述消费者组，用于协调和 offset 管理
      "kafka-cluster:AlterGroup"          # [新增] 允许 Flink 消费者提交 offset，对于消费者正常工作至关重要
      # "kafka-cluster:WriteData"         # [移除] Flink 任务作为消费者，不需要写入数据到 Kafka，遵循最小权限原则
    ]
    # 最佳实践是明确指定所有相关资源的 ARN
    resources = [
      aws_msk_cluster.kafka_cluster.arn,                                                                                             # 集群 ARN
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:topic/${aws_msk_cluster.kafka_cluster.cluster_name}/*", # [修改] 明确授权访问集群下的所有 Topic
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:group/${aws_msk_cluster.kafka_cluster.cluster_name}/*"  # [修改] 明确授权访问集群下的所有消费者组
    ]
  }

  # 该声明授予 Flink 任务写入 S3 的权限
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",                 # 允许 Flink 将数据对象写入 S3
      "s3:ListBucket",                # 允许 Flink 列出桶内对象，S3 Sink 的某些操作需要
      "s3:ListMultipartUploadParts",  # [新增] 支持 Flink S3 Sink 的多部分上传功能，对于大文件和 Exactly-Once 语义很重要
      "s3:AbortMultipartUpload"       # [新增] 允许在上传失败时中止多部分上传，避免产生不完整的文件和额外费用
      # "s3:GetObject"                # [移除] Flink 任务作为写入者，不需要从 S3 读取数据，遵循最小权限原则
    ]
    resources = [
      "arn:aws:s3:::${var.flink_output_bucket}",
      "arn:aws:s3:::${var.flink_output_bucket}/*"
    ]
  }

  # 该声明授予 ECS Exec 和 SSM Parameter Store 的访问权限
  statement {
    sid    = "SSMAccess"
    effect = "Allow"
    actions = [
      # 以下四个权限用于支持 ECS Exec 功能，方便调试
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ssm:GetParameter" # [新增] 允许 Flink 任务从 SSM Parameter Store 读取配置（例如，镜像 URL 或其他运行时参数）
    ]
    # 理想情况下，应将 ssm:GetParameter 的资源限定到具体的参数 ARN
    # 例如: "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:parameter/data-platform/dev/*"
    resources = ["*"]
  }
}

# --- S3 Bucket for Flink Output ---
# Flink 任务的输出 S3 桶，用于存储处理后的数据。
resource "aws_s3_bucket" "flink_output_bucket" {
  bucket = var.flink_output_bucket # 使用变量定义的桶名称
  acl    = "private"               # 默认设置为私有

  tags = {
    Name        = "${var.project_name}-${var.environment}-flink-output"
    Environment = var.environment
  }
}

# 阻止所有公共访问，确保 S3 桶的安全性
resource "aws_s3_bucket_public_access_block" "flink_output_bucket_public_access_block" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  block_public_acls       = true  # 阻止新的公共 ACL (访问控制列表) 应用于此桶或其对象。
  block_public_policy     = true  # 阻止附加任何授予公共访问权限的存储桶策略。
  ignore_public_acls      = true  # 忽略所有现有的公共 ACL，使它们失效。
  restrict_public_buckets = true  # 限制对具有公共策略的存储桶的访问，仅允许 AWS 服务和授权账户用户访问。
}

# 启用版本控制，防止意外删除或覆盖数据
resource "aws_s3_bucket_versioning" "flink_output_bucket_versioning" {
  bucket = aws_s3_bucket.flink_output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 启用默认服务器端加密，保护静态数据
resource "aws_s3_bucket_server_side_encryption_configuration" "flink_output_bucket_encryption" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # 使用 AES256 进行默认加密
    }
  }
}

# --- SSM Parameters for Application Configuration ---
# 将关键配置存入 SSM Parameter Store，以便 Flink 应用在运行时动态读取，实现基础设施与应用的解耦。

# 存储 Kafka Bootstrap Brokers 地址 (SASL/IAM)
resource "aws_ssm_parameter" "kafka_bootstrap_brokers" {
  name  = "/${var.project_name}/${var.environment}/kafka/bootstrap_brokers_sasl_iam"
  type  = "String"
  value = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
  
  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-bootstrap-brokers"
  }
}

# 存储 Kafka Topic 名称
resource "aws_ssm_parameter" "kafka_topic_name" {
  name  = "/${var.project_name}/${var.environment}/kafka/topic_name"
  type  = "String"
  value = kafka_topic.produce_events.name

  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-topic-name"
  }
}

# 存储 Flink 输出的 S3 桶名称
resource "aws_ssm_parameter" "flink_output_s3_bucket" {
  name  = "/${var.project_name}/${var.environment}/s3/flink_output_bucket"
  type  = "String"
  value = aws_s3_bucket.flink_output_bucket.bucket

  tags = {
    Name = "${var.project_name}-${var.environment}-flink-output-s3-bucket"
  }
}

# 存储 Kafka 消费者组 ID
resource "aws_ssm_parameter" "kafka_consumer_group_id" {
  name  = "/${var.project_name}/${var.environment}/kafka/consumer_group_id"
  type  = "String"
  # 核心：把我们决定的名字作为值存进去
  value = "${var.project_name}-${var.environment}-flink-consumer-group"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-consumer-group-id"
  }
}



# ------------------------------------------------------------------------------
# Application Load Balancer for Flink UI
# ------------------------------------------------------------------------------

# Reason for commenting out: The current AWS account does not support creating Load Balancers.
# This entire section is disabled until the account permissions are resolved.

# # 1. 创建一个公网的 Application Load Balancer
# resource "aws_lb" "flink_ui_alb" {
#   name               = "${var.project_name}-${var.environment}-flink-ui-alb"
#   internal           = false # false 表示这是公网 ALB
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb_sg.id] # 引用上面创建的 ALB 安全组
#   subnets            = var.public_subnet_ids         # 必须放置在公共子网中
# 
#   tags = {
#     Name = "${var.project_name}-${var.environment}-flink-ui-alb"
#   }
# }
# 
# # 2. 为 ALB 创建一个目标组，指向 Flink JobManager
# resource "aws_lb_target_group" "flink_ui_tg" {
#   name        = "${var.project_name}-${var.environment}-flink-ui-tg"
#   port        = 8081 # Flink UI 的端口
#   protocol    = "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "ip" # 因为我们使用的是 Fargate，所以目标类型是 IP
# 
#   health_check {
#     path                = "/" # Flink UI 的根路径可以作为健康检查点
#     protocol            = "HTTP"
#     matcher             = "200"
#     interval            = 30
#     timeout             = 10
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#   }
# }
# 
# # 3. 为 ALB 创建一个监听器，将公网 HTTP 80 端口的流量转发到目标组
# resource "aws_lb_listener" "flink_ui_listener" {
#   load_balancer_arn = aws_lb.flink_ui_alb.arn
#   port              = "80"
#   protocol          = "HTTP"
# 
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.flink_ui_tg.arn
#   }
# }



