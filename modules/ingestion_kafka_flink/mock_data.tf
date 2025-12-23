
# ==============================================================================
# Resources for Mock Data Generation Task
# ==============================================================================

# ------------------------------------------------------------------------------
# IAM Role and Policy for the Mock Data Task
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "mock_data_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# 信任策略 (Trust Policy)
# Assume Role Policy（信任策略）：你设置了角色的信任策略，告诉 AWS 只有ECS 任务可以假定这个角色来执行任务。这是身份验证的部分，确保只有 ECS 服务才可以使用这个角色。
resource "aws_iam_role" "mock_data_task_role" {
  name               = "${var.project_name}-${var.environment}-mock-data-task-role"
  assume_role_policy = data.aws_iam_policy_document.mock_data_task_assume_role.json
}

data "aws_iam_policy_document" "mock_data_task_policy" {
  # Statement 1: 授予集群级别的权限
  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",                 # 允许连接
      "kafka-cluster:DescribeCluster",         # 允许描述集群
      "kafka-cluster:WriteDataIdempotently"    # 允许幂等性写入 (防止消息重复)
    ]
    resources = [
      aws_msk_cluster.kafka_cluster.arn
    ]
  }

  # Statement 2: 授予 Topic 和 Transactional ID 级别的权限
  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:*Topic*",                 # 允许创建、描述、修改 Topic  https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/reference_policies_elements_action.html
      "kafka-cluster:WriteData",               # 允许向 Topic 写入数据
      "kafka-cluster:ReadData"                 # 某些客户端库在生产消息时也需要读取元数据
    ]
    resources = [
      # 授权操作所有 Topic
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:topic/${var.project_name}-${var.environment}-msk-cluster/*",
      # 授权操作所有 Transactional ID 事物
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:transactional-id/${var.project_name}-${var.environment}-msk-cluster/*"
    ]
  }

  # Statement 3: 保留你原来的 SSM 参数权限
  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:parameter/data-platform/${var.environment}/kafka/*"
    ]
  }
}

# 权限策略 (Permissions Policy)
# Permission Policy（权限策略）：你还定义了角色的权限策略，告诉 AWS 这个角色可以访问Kafka 集群和SSM 参数。这部分控制的是角色可以做什么操作，也就是角色拥有的权限。
resource "aws_iam_policy" "mock_data_task_policy" {
  name   = "${var.project_name}-${var.environment}-mock-data-task-policy"
  policy = data.aws_iam_policy_document.mock_data_task_policy.json
}

resource "aws_iam_role_policy_attachment" "mock_data_task_attachment" {
  role       = aws_iam_role.mock_data_task_role.name
  policy_arn = aws_iam_policy.mock_data_task_policy.arn
}

# ------------------------------------------------------------------------------
# ECS Task Definition for the Mock Data Task
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "mock_data_task" {
  family                   = "${var.project_name}-${var.environment}-mock-data-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  # Principle of Least Privilege 最小权限原则
  task_role_arn            = aws_iam_role.mock_data_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "mock-data-generator"
      image     = var.mockdata_image_url,
      linuxParameters = {
        initProcessEnabled = true # 用于配置容器的 Linux 特性，确保一些特定的进程管理功能（如 init 进程）正常工作。
      },
      executeCommandConfiguration = {
        enabled = true # 启用在容器内执行命令的功能，允许你通过 aws ecs execute-command 在容器中执行交互式命令进行调试和管理。
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "mock-data"
        }
      }
    }
  ])
}

# ------------------------------------------------------------------------------
# EventBridge Rule for Scheduled Mock Data Task
# ------------------------------------------------------------------------------
# 简单的回答：
# 在 Terraform (AWS Provider) 中，`aws_cloudwatch_event_rule` 就是 EventBridge Rule。虽然名字还叫 CloudWatch，但它实际上创建的就是 EventBridge 服务里的 Rule。

# 详细解释：

#  1. 历史原因 (History):
#      * 最初，这个服务叫 CloudWatch Events。
#      * Terraform 当时就开发了 aws_cloudwatch_event_rule 这个资源来对应它。
#      * 后来，AWS 把这个服务升级并改名为 EventBridge。
#      * 为了保持向后兼容性 (Backward Compatibility)，防止所有老用户的代码报错，Terraform 团队保留了 aws_cloudwatch_event_rule 这个名字。

#  2. 新资源 (`aws_scheduler_schedule` 等):
#      * Terraform 后来引入了 aws_cloudwatch_event_bus 等新资源来支持 EventBridge 的新特性（比如自定义总线）。
#      * 但对于最基础的 Rule（规则）和 Target（目标），大家依然普遍使用 aws_cloudwatch_event_rule。
#      * 注意：最近 AWS 推出了 EventBridge Scheduler，这是个更强大的定时任务服务，Terraform 里对应的是 aws_scheduler_schedule。但对于事件驱动（比如“任务失败了触发报警”），我们依然使用 aws_cloudwatch_event_rule。

# 结论：
# 虽然你在 Terraform 代码里写的是 resource "aws_cloudwatch_event_rule" ...，但当你去 AWS 控制台看的时候，请去 Amazon EventBridge -> Rules 页面找它。它们是同一个东西。
resource "aws_cloudwatch_event_rule" "mock_data_schedule_rule" {
  count               = var.mock_data_schedule == null ? 0 : 1
  name                = "${var.project_name}-${var.environment}-mock-data-schedule"
  description         = "Scheduled trigger for the mock data generator task."
  schedule_expression = var.mock_data_schedule
  state               = "DISABLED" # Disabled by default, enabled by the manual workflow
  # state               = "ENABLED" # Disabled by default, enabled by the manual workflow
}

resource "aws_cloudwatch_event_target" "mock_data_task_target" {
  count     = var.mock_data_schedule == null ? 0 : 1
  rule      = aws_cloudwatch_event_rule.mock_data_schedule_rule[0].name # 当你在资源中使用 count 后，Terraform 就会把这个资源视为一个列表（list），即使你只创建 1 个，它也变成了一个“数组形式”的资源。
  arn       = aws_ecs_cluster.main_cluster.arn
  role_arn  = aws_iam_role.eventbridge_to_ecs_role.arn # Assuming you have a role for EventBridge to run ECS tasks

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.mock_data_task.arn
    launch_type         = "FARGATE"
    enable_execute_command = true
    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [aws_security_group.ecs_tasks_sg.id]
      assign_public_ip = false # 在私有网络中运行，更安全
    }
  }
}

# This role allows EventBridge to run tasks on ECS
resource "aws_iam_role" "eventbridge_to_ecs_role" {
  name = "${var.project_name}-${var.environment}-eventbridge-to-ecs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "eventbridge_passrole_policy" {
  name = "${var.project_name}-${var.environment}-eventbridge-passrole"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.mock_data_task_role.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_passrole_attach" {
  role       = aws_iam_role.eventbridge_to_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"  # Use a custom PoLP version instead.
  # policy_arn = aws_iam_policy.eventbridge_passrole_policy.arn
}


