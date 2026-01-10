# --- ECR (Elastic Container Registry) ---
# Private registry for storing the Producer application's Docker images.
# 这是存放你 Producer 应用 Docker 镜像的私有仓库。
resource "aws_ecr_repository" "producer_repo" {
  name                 = "${var.project_name}-${var.environment}-producer-repo"
  # Allow tag overwriting to facilitate the use of 'latest' in dev environments.
  image_tag_mutability = "MUTABLE" # 允许覆盖标签，方便 dev 环境使用 'latest'

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-producer-repo"
  }
}

# --- ECS (Elastic Container Service) ---
resource "aws_ecs_cluster" "main_cluster" {
  name = "${var.project_name}-${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "producer_task" {
  family = "${var.project_name}-${var.environment}-flink-family"
  # Mandatory for Fargate as bridge or host modes are not allowed.
  # Other modes can be used for EC2 launch type, but Fargate is limited to awsvpc.
  # 对 Fargate 来说 必须，因为 Fargate 不允许使用 bridge 或 host 模式
  # 对 EC2 launch type 可以用其他模式，但 Fargate 只能 awsvpc
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  # cpu                      = "256"  # 0.25 vCPU
  # memory                   = "512"  # 512 MB
  cpu                = var.flink_task_cpu
  memory             = var.flink_task_memory
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_role.arn

  # =================================================================================
  # Container Definitions - Refactored from "Session Mode" to "Application Mode"
  # 容器定义 - 已从“会话模式”重构为“应用模式”
  # =================================================================================

  # ---------------------------------------------------------------------------------
  # Original "Session Mode" definition (Commented out)
  # 原“会话模式”定义 (已注释掉)
  # Reason: "Session Mode" decouples the Flink cluster lifecycle from the job lifecycle, 
  #          which doesn't align with the pure IaC philosophy of treating infra and app as one.
  #          It requires an extra step to submit jobs, unsuitable for continuous consumer scenarios.
  # 原因: “会话模式”将 Flink 集群的生命周期与作业的生命周期分离，不符合将
  #       基础设施与应用视为一体的纯 IaC 理念。它需要一个额外的步骤来提交作业，
  #       不适合持续运行的 consumer 场景。
  # ---------------------------------------------------------------------------------
  /*
  container_definitions = jsonencode([
    # --- Job Manager 容器 ---
    {
      name  = "jobmanager",
      image = var.flink_image_url,
      essential = true,
      command = ["start-foreground"],
      entryPoint = [
        "/opt/flink/bin/jobmanager.sh"
      ],
      environment = [
        { name = "FLINK_PROPERTIES_jobmanager.rpc.address", value = "jobmanager" }
      ],
      portMappings = [
        { containerPort = 8081, hostPort = 8081, protocol = "tcp" },
        { containerPort = 6123, hostPort = 6123, protocol = "tcp" }
      ],
      linuxParameters = {
        initProcessEnabled = true
      },
      executeCommandConfiguration = {
        enabled = true
      },
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "jobmanager"
        }
      }
    },
    # --- Task Manager 容器 ---
    {
      name = "taskmanager",
      image     = var.flink_image_url,
      essential = true,
      command   = ["start-foreground"],
      entryPoint = [
        "/opt/flink/bin/taskmanager.sh"
      ],
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
  */

  # ---------------------------------------------------------------------------------
  # New "Application Mode" definition
  # 新“应用模式”定义
  # Explanation:
  # 1. Single Container: "Application Mode" bundles Flink cluster and app as a unit. No separate JM/TM containers needed.
  # 2. Entrypoint: Removed 'entrypoint' and 'command' to use Dockerfile definitions.
  # 3. Port Mapping: Still keeping 8081 for Flink Web UI.
  # 解释:
  # 1. 单一容器: “应用模式”将 Flink 集群和应用捆绑为一个单元。不再需要区分
  #              JobManager 和 TaskManager，整个应用在一个容器内启动和协调。
  # 2. 依赖 Dockerfile 的 ENTRYPOINT: 我们移除了 Terraform 中的 'entryPoint' 和
  #                                  'command'。这使得 ECS 会执行 Docker 镜像中
  #                                  定义的 ENTRYPOINT，从而以“应用模式”启动 Flink 作业。
  # 3. 端口映射: 仍然保留 8081 端口，以便可以访问 Flink 作业的 Web UI 进行监控。
  # ---------------------------------------------------------------------------------
  # container_definitions = jsonencode([
  #   {
  #     name      = "flink-application", # 单一容器，名称可以自定义
  #     image     = var.flink_image_url,
  #     essential = true,

  #     # 注意: 'entryPoint' 和 'command' 已被移除，以使用 Dockerfile 中的定义。
  #     # 你的 Dockerfile 应该包含类似这样的命令:
  #     # ENTRYPOINT ["/opt/flink/bin/flink-entrypoint.sh", "run-application", ...]

  #     # 端口映射，用于访问 Flink Web UI
  #     portMappings = [
  #       { containerPort = 8081, hostPort = 8081, protocol = "tcp" }
  #     ],

  #     # ---------------------------------------------------------------------------------
  #     # 🔥 Final authoritative fix: Use explicit env vars to pass Flink config
  #     # 🔥 最终的、最权威的修正: 使用独立的、明确的环境变量来传递 Flink 配置
  #     # ---------------------------------------------------------------------------------
  #     environment = [
  #       # Reason: Resolve "NoResourceAvailableException". Ensures Flink knows its slot count.
  #       # 原因: 解决 "NoResourceAvailableException" 错误。
  #       # 解释: 这是向 Flink 明确传递配置的最可靠方法。环境变量 FLINK_TASKMANAGER_NUMBEROFTASKSLOTS
  #       #       会被 Flink 启动脚本自动转换为配置项 "taskmanager.numberOfTaskSlots"。
  #       #       这确保了 Flink 知道它有多少可用的处理槽。
  #       {
  #         name  = "FLINK_TASKMANAGER_NUMBEROFTASKSLOTS",
  #         value = "2"
  #       },
  #       # Reason: Improve stability. Switch state backend to RocksDB to prevent OOM.
  #       # 原因: 提高生产环境下的稳定性和可扩展性。
  #       # 解释: 环境变量 FLINK_STATE_BACKEND 会被转换为配置项 "state.backend"。
  #       #       我们将状态后端从默认的内存(HashMap)切换到基于磁盘的 RocksDB，
  #       #       以防止因状态数据过大导致的内存溢出，这是 Flink 生产部署的最佳实践。
  #       {
  #         name  = "FLINK_STATE_BACKEND",
  #         value = "rocksdb"
  #       },
  #       # Reason: Solve random crashes. Explicitly tell Flink the total process memory.
  #       # 原因: 解决因内存不足导致的随机崩溃和重启循环。
  #       # 解释: 🔥 这是最关键的配置。我们明确告诉 Flink 进程它总共能用多少内存。
  #       #       这个值应该略小于容器的总内存 (我们在 dev.tfvars 中设置为 4096MB)，
  #       #       为操作系统和 JVM 本身留出一些开销。Flink 会基于这个总大小，
  #       #       自动计算堆内存、网络内存、RocksDB 缓存等各个部分的大小。
  #       {
  #         name  = "FLINK_TASKMANAGER_MEMORY_PROCESS_SIZE",
  #         value = "3686m" # 约等于 4096MB * 0.9
  #       }
  #     ],

  #     # 其他配置保持不变
  #     linuxParameters = {
  #       initProcessEnabled = true
  #     },
  #     executeCommandConfiguration = {
  #       enabled = true
  #     },
  #     logConfiguration = {
  #       logDriver = "awslogs",
  #       options = {
  #         "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
  #         "awslogs-region"        = var.aws_region,
  #         "awslogs-stream-prefix" = "flink-application" # 使用统一的日志前缀
  #       }
  #     }
  #   }
  # ])

  container_definitions = jsonencode([
    # =================================================================================
    # Container 1: JobManager (Master)
    # =================================================================================
    {
      name      = "jobmanager",
      image     = var.flink_image_url,
      essential = true, # 如果 JM 挂了，整个 Task 重启

      # Dockerfile 的默认 CMD 是 ["standalone-job", ...]，这里不需要覆盖
      # 它是 Application Mode 的入口

      # 端口映射：暴露 Web UI
      portMappings = [
        { containerPort = 8081, protocol = "tcp" }
      ],

      # 环境变量配置
      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT",  value = var.environment },
        { name = "AWS_REGION",   value = var.aws_region },
        {
          name  = "FLINK_PROPERTIES",
          value = <<EOT
            # --- Basic Network Config ---
            # --- 基础网络配置 ---
            jobmanager.rpc.address: localhost
            # Bind to 0.0.0.0 to allow external access to Web UI. 
            # Don't use localhost here or you won't be able to connect.
            # 关键修改：改为 0.0.0.0，否则外部浏览器无法访问 Web UI，记着不能用 localhost，用它会连接不上 web ui. 0.0.0.0 是一个特殊地址，意思是“监听这台机器上的所有 IP 地址”。
            rest.address: 0.0.0.0
            # rest.bind-address: localhost

            # --- Resource Scheduling Config ---
            # --- 资源调度配置 ---
            # Must be consistent with TaskManager's slot count.
            # 必须与 TaskManager 的 Slot 数量一致
            taskmanager.numberOfTaskSlots: 1
            parallelism.default: 1

            # --- State Backend (RocksDB) ---
            # --- 状态后端 (RocksDB) ---
            state.backend: rocksdb
            state.checkpoints.dir: s3://${var.flink_output_bucket}/checkpoints/
            state.savepoints.dir: s3://${var.flink_output_bucket}/savepoints/
            execution.checkpointing.interval: 60000
            execution.checkpointing.mode: EXACTLY_ONCE

            # --- S3 访问配置 用minio的方式 已经注释掉了，如果是本地的话，就用这个。 ---
            # s3.endpoint: http://minio:9000
            # s3.path.style.access: true
            # s3.access-key: minioadmin
            # s3.secret-key: minioadmin

            # --- Memory Config (Important) ---
            # --- 内存配置 (重要) ---
            # JobManager doesn't need much memory; save it for TM.
            # JobManager 不需要太多内存，省下来给 TM
            jobmanager.memory.process.size: 1024m
            EOT
        }
      ],

      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "jobmanager"
        }
      }
    },

    # =================================================================================
    # Container 2: TaskManager (Worker)
    # =================================================================================
    {
      name      = "taskmanager",
      image     = var.flink_image_url, # 使用同一个镜像
      essential = true, # 如果 TM 挂了，Task 也应该重启恢复

      # Key: Override CMD to force startup in TaskManager mode.
      # 🔥 关键：覆盖 CMD，强制以 TaskManager 模式启动
      command   = ["taskmanager"],

      # 环境变量配置
      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT",  value = var.environment },
        { name = "AWS_REGION",   value = var.aws_region },
        {
          name  = "FLINK_PROPERTIES",
          value = <<EOT
            # --- Connect to Master ---
            # --- 连接 Master ---
            # Since they are in the same Task (awsvpc), localhost works.
            # 因为在同一个 Task (awsvpc) 里，localhost 就能通
            jobmanager.rpc.address: localhost
            taskmanager.host: localhost

            # --- Resource Config ---
            # --- 资源配置 ---
            taskmanager.numberOfTaskSlots: 1
            taskmanager.memory.process.size: 2500m 
            # (Note: JM(1G) + TM(2.5G) < Total Task Memory(4G), leaving 500MB for the OS)
            # (注意: JM(1G) + TM(2.5G) < Task总内存(4G)，留 500MB 给系统)

            # --- 其他配置 (必须保持一致) ---
            # state.backend: rocksdb
            # s3.endpoint: http://minio:9000
            # s3.path.style.access: true
            # s3.access-key: minioadmin
            # s3.secret-key: minioadmin
            EOT
        }
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

# ECS Service: Runs and maintains instances of the "blueprint".
# Ensures the specified number of tasks are running and handles network config.
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
    subnets          = var.public_subnet_ids # 改为使用公共子网为了访问 flink 8081
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true # 启用公网 IP 分配
  }

  # Ensure the service automatically deploys new versions after task definition updates.
  # 确保在任务定义更新后，服务能自动部署新版本
  force_new_deployment = true

  #   # 原因: ALB 已被禁用。
  #   # 更新: container_name 已从 "jobmanager" 修改为 "flink-application"，以匹配新的“应用模式”单容器定义。
  #   target_group_arn = aws_lb_target_group.flink_ui_tg.arn
  #   container_name   = "flink-application" # 必须与容器定义中的 Flink 应用容器名称完全匹配
  #   container_port   = 8081
  # }
}

# Scale down desired task count to 0 upon destruction.
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
    # Step 1: Scale down the service to 0. This handles tasks managed by the service.
    command    = "aws ecs update-service --cluster ${self.triggers.cluster_name} --service ${self.triggers.service_name} --desired-count 0 --region ${self.triggers.aws_region}"
    on_failure = continue # 如果服务已经不存在或不活跃，忽略错误并继续销毁过程
  }

  # Key Fix: Add a provisioner to stop all non-service managed tasks (e.g., started by EventBridge).
  # 🔥 关键修正: 添加一个新的 provisioner 来停止所有非 Service 管理的任务 (例如由 EventBridge 启动的任务)
  provisioner "local-exec" {
    when = destroy
    # Step 2: List all remaining running tasks in the cluster and forcefully stop them.
    # This is necessary to remove tasks started by EventBridge, which would otherwise block cluster deletion.
    command = <<EOT
      TASKS=$(aws ecs list-tasks --cluster ${self.triggers.cluster_name} --region ${self.triggers.aws_region} --query 'taskArns[*]' --output text)
      if [ -n "$TASKS" ]; then
        echo "Stopping tasks in cluster ${self.triggers.cluster_name}: $TASKS"
        for task in $TASKS; do
          aws ecs stop-task --cluster ${self.triggers.cluster_name} --task $task --region ${self.triggers.aws_region} --reason "Terraform destroy"
        done
      else
        echo "No running tasks found in cluster ${self.triggers.cluster_name} to stop."
      fi
    EOT
    on_failure = continue # 如果没有任务或停止失败，也继续执行
  }
}

# CloudWatch Log Group - Updated name to adapt to Flink.
# CloudWatch 日志组 - 更新名称以适配 Flink
resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}-flink-family"
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

# Create ECS client Security Group.
# 创建 ECS client SG（示例）
resource "aws_security_group" "ecs_tasks_sg" {
  name   = "${var.environment}-ecs-tasks-sg"
  vpc_id = var.vpc_id

  # Allow all outbound traffic.
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

  # Reason for adding: To allow access to the Flink UI on port 8081.
  # Security improvement: Restricting access to ONLY the Runner/Bastion security group.
  ingress {
    description     = "Allow Flink UI access ONLY via Bastion/Runner"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [data.aws_security_group.runner_sg.id] # 只允许 Runner 访问
  }
}

# ECS task executed role
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

# Attach managed policies (AWS recommended) for basic capabilities: logging, ECR, S3 access.
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

# Create an inline policy to grant read access to specific secrets.
# 为这个角色创建一个内联策略，明确授予读取特定 Secret 的权限
# 专门用来创建并附加 inline policy，只能属于某一个角色
resource "aws_iam_role_policy" "read_kafka_secret_policy" {
  name   = "read-kafka-secret-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

# 1. ECS Task Execution Role Trust Policy. Grants ECS Agent permission to pull images and send logs.
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

# Generate AssumeRole Trust Policy for ECS Task Role.
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

# Least Privilege Permission Policy.
# 最小权限策略                            权限策略（Permission Policy）
data "aws_iam_policy_document" "ecs_task_policy" {
  # This statement grants the Flink task access to the Kafka cluster.
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
    # Best practice: explicitly specify the ARNs of all relevant resources.
    # 最佳实践是明确指定所有相关资源的 ARN
    resources = [
      aws_msk_cluster.kafka_cluster.arn,                                                                                             # 集群 ARN
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:topic/${aws_msk_cluster.kafka_cluster.cluster_name}/*", # [修改] 明确授权访问集群下的所有 Topic
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:group/${aws_msk_cluster.kafka_cluster.cluster_name}/*"  # [修改] 明确授权访问集群下的所有消费者组
    ]
  }

  # This statement grants the Flink task permission to write to S3.
  # 该声明授予 Flink 任务写入 S3 的权限
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",                 # 允许 Flink 将数据对象写入 S3
      "s3:ListBucket",                # 允许 Flink 列出桶内对象，S3 Sink 的某些操作需要
      "s3:ListMultipartUploadParts",  # [新增] 支持 Flink S3 Sink 的多部分上传功能，对于大文件和 Exactly-Once 语义很重要
      "s3:AbortMultipartUpload",      # [新增] 允许在上传失败时中止多部分上传，避免产生不完整的文件和额外费用
      "s3:DeleteObject",              # [新增] 允许 Flink 删除 S3 对象，用于 Checkpoint 清理等操作
      "s3:GetObject"                  # [重新加入] 允许 Flink 在故障恢复时从 Checkpoint 读取状态
    ]
    resources = [
      "arn:aws:s3:::${var.flink_output_bucket}",
      "arn:aws:s3:::${var.flink_output_bucket}/*"
    ]
  }

  # This statement grants access to ECS Exec and SSM Parameter Store.
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
    # Scope down SSM access to project parameters.
    # 理想情况下，应将 ssm:GetParameter 的资源限定到具体的参数 ARN
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }
}

# Flink output S3 bucket, used for storing processed data.
# --- S3 Bucket for Flink Output ---
# Flink 任务的输出 S3 桶，用于存储处理后的数据。
resource "aws_s3_bucket" "flink_output_bucket" {
  bucket        = var.flink_output_bucket # 使用变量定义的桶名称
  force_destroy = true                    # 强制删除，即使桶不为空

  tags = {
    Name        = "${var.project_name}-${var.environment}-flink-output"
  }
}

# Lifecycle management to expire old checkpoints and non-current versions.
# Logic: Separate business data from system state data; recycle state data to save costs.
# --- S3 桶生命周期管理 ---
# 核心逻辑：区分业务数据与系统状态数据，对状态数据进行垃圾回收以节省成本。
resource "aws_s3_bucket_lifecycle_configuration" "flink_output_lifecycle" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  # Rule 0: Cleanup old versions (Cost Optimization)
  # 规则 0: 清理旧版本 (Cost Optimization)
  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    # 如果文件被覆盖/删除，其历史版本保留 30 天后彻底清除
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule 1: Expire old checkpoints (auto-generated by Flink)
  # 规则 1: 自动清理过期的 Checkpoints (Flink 自动生成)
  rule {
    id     = "expire-checkpoints"
    status = "Enabled"

    filter {
      prefix = "checkpoints/"
    }

    expiration {
      days = 3 # 保留最近 3 天的快照即可
    }
  }

  # Rule 2: Expire old savepoints (manually triggered)
  # 规则 2: 自动清理过期的 Savepoints (手动触发)
  rule {
    id     = "expire-savepoints"
    status = "Enabled"

    filter {
      prefix = "savepoints/"
    }

    expiration {
      days = 7 # 手动存档保留时间稍长
    }
  }
}

# Block all public access to ensure S3 bucket security.
# 阻止所有公共访问，确保 S3 桶的安全性
resource "aws_s3_bucket_public_access_block" "flink_output_bucket_public_access_block" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  block_public_acls       = true  # 阻止新的公共 ACL (访问控制列表) 应用于此桶或其对象。
  block_public_policy     = true  # 阻止附加任何授予公共访问权限的存储桶策略。
  ignore_public_acls      = true  # 忽略所有现有的公共 ACL，使它们失效。
  restrict_public_buckets = true  # 限制对具有公共策略的存储桶的访问，仅允许 AWS 服务和授权账户用户访问。
}

# Enable versioning to prevent accidental deletion or overwriting.
# 启用版本控制，防止意外删除或覆盖数据
# 对于生产级数据湖，开启 Versioning 是合规要求。
resource "aws_s3_bucket_versioning" "flink_output_bucket_versioning" {
  bucket = aws_s3_bucket.flink_output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable default server-side encryption to protect data at rest.
# 启用默认服务器端加密，保护静态数据
resource "aws_s3_bucket_server_side_encryption_configuration" "flink_output_bucket_encryption" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # 使用 AES256 进行默认加密
    }
  }
}

# Store critical configs in SSM for dynamic reading, decoupling infra and app.
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

# Store our chosen name as the value.
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

# 存储 Flink DLQ 的 S3 桶路径
resource "aws_ssm_parameter" "flink_dlq_s3_path" {
  name  = "/${var.project_name}/${var.environment}/s3/flink_dlq_path"
  type  = "String"
  value = "s3://${aws_s3_bucket.flink_output_bucket.bucket}/dlq/"

  tags = {
    Name = "${var.project_name}-${var.environment}-flink-dlq-path"
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