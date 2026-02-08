# --- ECS (Elastic Container Service) ---
resource "aws_ecs_cluster" "main_cluster" {
  name = "${var.project_name}-${var.environment}-cluster"
}

resource "aws_ecs_task_definition" "producer_task" {
  family                   = "${var.project_name}-${var.environment}-flink-family"
  # Fargate requires 'awsvpc' network mode.
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.flink_task_cpu
  memory                   = var.flink_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Application Mode: bundles Flink cluster and application as a single unit.
  container_definitions = jsonencode([
    # Container 1: JobManager (Master)
    {
      name      = "jobmanager",
      image     = var.flink_image_url,
      essential = true, 
      portMappings = [
        { containerPort = 8081, protocol = "tcp" }
      ],
      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT",  value = var.environment },
        { name = "AWS_REGION",   value = var.aws_region },
        {
          name  = "FLINK_PROPERTIES",
          value = <<EOT
            # Network Config
            jobmanager.rpc.address: localhost
            # Bind to 0.0.0.0 to allow Web UI access.
            rest.address: 0.0.0.0

            # Resource Scheduling (Adaptive Mode)
            taskmanager.numberOfTaskSlots: 1
            # parallelism.default: 1
            jobmanager.scheduler: adaptive

            # State Backend (RocksDB)
            state.backend: rocksdb
            state.checkpoints.dir: s3://${var.flink_output_bucket}/checkpoints/
            state.savepoints.dir: s3://${var.flink_output_bucket}/savepoints/
            execution.checkpointing.interval: 60000
            execution.checkpointing.mode: EXACTLY_ONCE

            # Memory Config
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

    # Container 2: TaskManager (Worker)
    {
      name      = "taskmanager",
      image     = var.flink_image_url,
      essential = true, 
      command   = ["taskmanager"],
      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "ENVIRONMENT",  value = var.environment },
        { name = "AWS_REGION",   value = var.aws_region },
        {
          name  = "FLINK_PROPERTIES",
          value = <<EOT
            # Connect to Master
            jobmanager.rpc.address: localhost
            taskmanager.host: localhost

            # Resource Config
            taskmanager.numberOfTaskSlots: 1
            taskmanager.memory.process.size: 2500m 
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

# ECS Service: Manages task instances and network configuration.
resource "aws_ecs_service" "producer_service" {
  name                   = "${var.project_name}-${var.environment}-producer-service"
  cluster                = aws_ecs_cluster.main_cluster.id
  task_definition        = aws_ecs_task_definition.producer_task.arn
  desired_count          = 1 
  launch_type            = "FARGATE"
  enable_execute_command = true

  network_configuration {
    # Public subnets used here to facilitate direct Flink UI access for development.
    subnets          = var.public_subnet_ids 
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true 
  }

  force_new_deployment = true
}

# Graceful shutdown: scale down service and stop standalone tasks during destruction.
resource "null_resource" "stop_producer_service" {
  depends_on = [aws_ecs_service.producer_service]

  triggers = {
    cluster_name = aws_ecs_service.producer_service.cluster
    service_name = aws_ecs_service.producer_service.name
    aws_region   = var.aws_region
  }

  provisioner "local-exec" {
    when = destroy
    command    = "aws ecs update-service --cluster ${self.triggers.cluster_name} --service ${self.triggers.service_name} --desired-count 0 --region ${self.triggers.aws_region}"
    on_failure = continue 
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOT
      TASKS=$(aws ecs list-tasks --cluster ${self.triggers.cluster_name} --region ${self.triggers.aws_region} --query 'taskArns[*]' --output text)
      if [ -n "$TASKS" ]; then
        echo "Stopping tasks in cluster ${self.triggers.cluster_name}: $TASKS"
        for task in $TASKS; do
          aws ecs stop-task --cluster ${self.triggers.cluster_name} --task $task --region ${self.triggers.aws_region} --reason "Terraform destroy"
        done
      fi
    EOT
    on_failure = continue 
  }
}

resource "aws_cloudwatch_log_group" "flink_logs" {
  name              = "/ecs/${var.project_name}-${var.environment}-flink-family"
  retention_in_days = 14
}

# ECS Task Security Group
resource "aws_security_group" "ecs_tasks_sg" {
  name   = "${var.environment}-ecs-tasks-sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-ecs-tasks-sg" }

  # Restrict Flink UI access to the management runner security group.
  ingress {
    description     = "Allow Flink UI access via Bastion/Runner"
    from_port       = 8081
    to_port         = 8081
    protocol        = "tcp"
    security_groups = [data.aws_security_group.runner_sg.id]
  }
}

# IAM Role for ECS Task Execution (pull images, send logs).
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task (application permissions).
resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-${var.environment}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy" "ecs_task_policy_attachment" {
  name   = "ecs-task-policy"
  role   = aws_iam_role.ecs_task_role.id
  policy = data.aws_iam_policy_document.ecs_task_policy.json
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Minimum privilege policy for Flink tasks.
data "aws_iam_policy_document" "ecs_task_policy" {
  # Kafka Cluster Connectivity
  statement {
    sid    = "KafkaClusterAccess"
    effect = "Allow"
    actions = [
      "kafka-cluster:DescribeCluster",
      "kafka-cluster:Connect",
      "kafka-cluster:DescribeTopic",
      "kafka-cluster:ReadData",
      "kafka-cluster:DescribeGroup",
      "kafka-cluster:AlterGroup"
    ]
    resources = [
      aws_msk_cluster.kafka_cluster.arn,
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:topic/${aws_msk_cluster.kafka_cluster.cluster_name}/*",
      "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.me.account_id}:group/${aws_msk_cluster.kafka_cluster.cluster_name}/*"
    ]
  }

  # S3 Data Lake Access
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:ListBucket",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.flink_output_bucket}",
      "arn:aws:s3:::${var.flink_output_bucket}/*"
    ]
  }

  # ECS Exec and SSM configuration access
  statement {
    sid    = "SSMAccess"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ssm:GetParameter" 
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.me.account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }
}

# --- S3 Bucket for Flink Output and State ---
resource "aws_s3_bucket" "flink_output_bucket" {
  bucket        = var.flink_output_bucket 
  force_destroy = true                    

  tags = {
    Name = "${var.project_name}-${var.environment}-flink-output"
  }
}

# S3 Lifecycle: separate business data from system state and recycle old state.
resource "aws_s3_bucket_lifecycle_configuration" "flink_output_lifecycle" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  # Rule 0: Cleanup old non-current versions.
  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  # Rule 1: Expire old Flink checkpoints.
  rule {
    id     = "expire-checkpoints"
    status = "Enabled"
    filter {
      prefix = "checkpoints/"
    }
    expiration {
      days = 3 
    }
  }

  # Rule 2: Expire old savepoints (longer retention).
  rule {
    id     = "expire-savepoints"
    status = "Enabled"
    filter {
      prefix = "savepoints/"
    }
    expiration {
      days = 7 
    }
  }
}

# Block public access to the data lake.
resource "aws_s3_bucket_public_access_block" "flink_output_bucket_public_access_block" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  block_public_acls       = true  
  block_public_policy     = true  
  ignore_public_acls      = true  
  restrict_public_buckets = true  
}

resource "aws_s3_bucket_versioning" "flink_output_bucket_versioning" {
  bucket = aws_s3_bucket.flink_output_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flink_output_bucket_encryption" {
  bucket = aws_s3_bucket.flink_output_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" 
    }
  }
}

# --- SSM Parameters for Application Decoupling ---
resource "aws_ssm_parameter" "kafka_bootstrap_brokers" {
  name  = "/${var.project_name}/${var.environment}/kafka/bootstrap_brokers_sasl_iam"
  type  = "String"
  value = aws_msk_cluster.kafka_cluster.bootstrap_brokers_sasl_iam
  
  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-bootstrap-brokers"
  }
}

resource "aws_ssm_parameter" "kafka_topic_name" {
  name  = "/${var.project_name}/${var.environment}/kafka/topic_name"
  type  = "String"
  value = kafka_topic.produce_events.name

  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-topic-name"
  }
}

resource "aws_ssm_parameter" "flink_output_s3_bucket" {
  name  = "/${var.project_name}/${var.environment}/s3/flink_output_bucket"
  type  = "String"
  value = aws_s3_bucket.flink_output_bucket.bucket

  tags = {
    Name = "${var.project_name}-${var.environment}-flink-output-s3-bucket"
  }
}

resource "aws_ssm_parameter" "kafka_consumer_group_id" {
  name  = "/${var.project_name}/${var.environment}/kafka/consumer_group_id"
  type  = "String"
  value = "${var.project_name}-${var.environment}-flink-consumer-group"
  
  tags = {
    Name = "${var.project_name}-${var.environment}-kafka-consumer-group-id"
  }
}

resource "aws_ssm_parameter" "flink_dlq_s3_path" {
  name  = "/${var.project_name}/${var.environment}/s3/flink_dlq_path"
  type  = "String"
  value = "s3://${aws_s3_bucket.flink_output_bucket.bucket}/dlq/"

  tags = {
    Name = "${var.project_name}-${var.environment}-flink-dlq-path"
  }
}
