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

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = false # 我们的 producer 在私有网络中运行，更安全
  }

  # 确保在任务定义更新后，服务能自动部署新版本
  force_new_deployment = true
}

# CloudWatch 日志组 - 更新名称以适配 Flink
resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.flink_task_family}"
  retention_in_days = 14
}

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



