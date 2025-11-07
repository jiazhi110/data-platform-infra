
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
  statement {
    actions = [
      "kafka:DescribeCluster",
      "kafka:GetBootstrapBrokers",
      "kafka:DescribeTopic",
      "kafka:ListTopics",
      "kafka:WriteData"
    ]
    resources = [
      aws_msk_cluster.kafka_cluster.arn
    ]
  }

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
  name   = "${var.project_name}-${var.environment}-MockDataTaskPolicy"
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


