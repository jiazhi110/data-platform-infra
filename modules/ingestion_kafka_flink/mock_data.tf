
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
}

resource "aws_iam_role_policy" "mock_data_task_policy" {
  name   = "MockDataTaskPolicy"
  role   = aws_iam_role.mock_data_task_role.id
  policy = data.aws_iam_policy_document.mock_data_task_policy.json
}

# ------------------------------------------------------------------------------
# ECS Task Definition for the Mock Data Task
# ------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "mock_data_task" {
  family                   = "${var.project_name}-mock-data-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.mock_data_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "mock-data-generator"
      image     = var.mock_data_image
      command   = var.mock_data_command
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
}

resource "aws_cloudwatch_event_target" "mock_data_task_target" {
  count     = var.mock_data_schedule == null ? 0 : 1
  rule      = aws_cloudwatch_event_rule.mock_data_schedule_rule[0].name
  arn       = aws_ecs_cluster.main_cluster.arn
  role_arn  = aws_iam_role.eventbridge_to_ecs_role.arn # Assuming you have a role for EventBridge to run ECS tasks

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.mock_data_task.arn
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = var.private_subnet_ids
      assign_public_ip = false
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

resource "aws_iam_role_policy_attachment" "eventbridge_to_ecs_policy" {
  role       = aws_iam_role.eventbridge_to_ecs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}

