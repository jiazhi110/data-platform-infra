# ==============================================================================
# Resources for Mock Data Generation Task
# ==============================================================================

# --- IAM Role and Policy for the Mock Data Task ---

data "aws_iam_policy_document" "mock_data_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# IAM Role Trust Policy for the Mock Data ECS Task.
resource "aws_iam_role" "mock_data_task_role" {
  name               = "${var.project_name}-${var.environment}-mock-data-task-role"
  assume_role_policy = data.aws_iam_policy_document.mock_data_task_assume_role.json
}

data "aws_iam_policy_document" "mock_data_task_policy" {
  # Statement 1: Grant cluster-level permissions (Connect, Describe, Idempotent Write).
  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:WriteDataIdempotently" 
    ]
    resources = [
      aws_msk_cluster.kafka_cluster.arn
    ]
  }

  # Statement 2: Grant permissions at the Topic and Transactional ID levels.
  statement {
    effect = "Allow"
    actions = [
      "kafka-cluster:*Topic*",
      "kafka-cluster:WriteData",
      "kafka-cluster:ReadData"
    ]
    resources = [
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:topic/${var.project_name}-${var.environment}-msk-cluster/*",
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:transactional-id/${var.project_name}-${var.environment}-msk-cluster/*"
    ]
  }

  # Statement 3: Grant access to Kafka-related SSM parameters.
  statement {
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }
}

# IAM Permissions Policy for the Mock Data Task.
resource "aws_iam_policy" "mock_data_task_policy" {
  name   = "${var.project_name}-${var.environment}-mock-data-task-policy"
  policy = data.aws_iam_policy_document.mock_data_task_policy.json
}

resource "aws_iam_role_policy_attachment" "mock_data_task_attachment" {
  role       = aws_iam_role.mock_data_task_role.name
  policy_arn = aws_iam_policy.mock_data_task_policy.arn
}

# --- ECS Task Definition for the Mock Data Generator ---

resource "aws_ecs_task_definition" "mock_data_task" {
  family                   = "${var.project_name}-${var.environment}-mock-data-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn  
  task_role_arn            = aws_iam_role.mock_data_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "mock-data-generator"
      image     = var.mockdata_image_url,
      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT",  value = var.environment },
        { name = "AWS_REGION",   value = var.aws_region }
      ],
      linuxParameters = {
        initProcessEnabled = true 
      },
      executeCommandConfiguration = {
        enabled = true 
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.flink_logs.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "mock-data"
        }
      }
    }
  ])
}

# --- EventBridge Rule for Scheduled Mock Data Generation ---
# Note: In the AWS Provider, aws_cloudwatch_event_rule is the resource for EventBridge Rules.
resource "aws_cloudwatch_event_rule" "mock_data_schedule_rule" {
  count               = var.mock_data_schedule == null ? 0 : 1
  name                = "${var.project_name}-${var.environment}-mock-data-schedule"
  description         = "Scheduled trigger for the mock data generator task."
  schedule_expression = var.mock_data_schedule
  state               = "DISABLED" 
}

# ECS target for the scheduled task.
resource "aws_cloudwatch_event_target" "mock_data_task_target" {
  count     = var.mock_data_schedule == null ? 0 : 1
  rule      = aws_cloudwatch_event_rule.mock_data_schedule_rule[0].name 
  arn       = aws_ecs_cluster.main_cluster.arn
  role_arn  = aws_iam_role.eventbridge_to_ecs_role.arn 

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.mock_data_task.arn
    launch_type         = "FARGATE"
    enable_execute_command = true
    network_configuration {
      subnets          = var.private_subnet_ids
      security_groups  = [aws_security_group.ecs_tasks_sg.id]
      assign_public_ip = false 
    }
  }
}

# IAM Role for EventBridge to execute ECS tasks.
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
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceEventsRole"
}