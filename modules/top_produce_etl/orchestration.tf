# ------------------------------------------------------------------------------
# AWS Step Functions Orchestration
# ------------------------------------------------------------------------------
# Why use Step Functions? To orchestrate Glue Job and Crawler into a resilient, automated pipeline.
# 为什么使用 Step Functions？
# 为了将分散的 ETL 组件（Glue Job 和 Crawler）串联成一个自动化的、具备错误处理能力的流水线。
# ------------------------------------------------------------------------------

# 1. Step Functions IAM Role
resource "aws_iam_role" "sfn_role" {
  name = "${var.project_name}-${var.environment}-sfn-orchestrator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

# Grant Step Functions minimum permissions required for pipeline execution.
# 授予 Step Functions 执行流水线所需的最小权限
resource "aws_iam_role_policy" "sfn_policy" {
  name = "sfn-orchestration-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow managing Glue Jobs (Start/Stop/Get).
        # 允许管理 Glue 作业
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:BatchStopJobRun"
        ]
        Resource = aws_glue_job.top_produce_etl_job.arn
      },
      {
        # Allow managing Glue Crawlers.
        # 允许管理 Crawler
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = aws_glue_crawler.etl_crawler.arn
      },
      {
        # Allow publishing alerts to SNS.
        # 允许发送报警通知
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.sns_alert_topic_arn
      }
    ]
  })
}

# 2. State Machine Definition
# 2. State Machine 定义
resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "${var.project_name}-${var.environment}-etl-workflow"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Orchestrates Glue ETL Job and Crawler with Error Handling"
    StartAt = "RunETLJob"
    States = {
      # Step 1: Run Glue ETL Job
      # 步骤 1: 运行 Glue ETL 任务
      "RunETLJob" = {
        Type     = "Task"
        # Use .sync pattern to wait for job completion automatically.
        # .sync 模式会自动等待 Job 完成
        Resource = "arn:aws:states:::glue:startJobRun.sync" 
        Parameters = {
          JobName = aws_glue_job.top_produce_etl_job.name
        }
        # Resilience pattern - Retry on failure with exponential backoff.
        # 自动重试策略 (Resilience)
        Retry = [{
          ErrorEquals     = ["Glue.AWSGlueException", "States.TaskFailed"],
          IntervalSeconds = 60,  # 失败后等待 60 秒
          MaxAttempts     = 3,   # 最多重试 3 次
          BackoffRate     = 2.0  # 每次等待时间翻倍
        }]
        Next = "RunCrawler"
        # Circuit Breaker - Catch errors and alert immediately if retries fail.
        # 错误捕获：如果重试后依然失败，直接跳到报警步骤
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "NotifyFailure"
        }]
      }

      # Step 2: Run Crawler to update metadata after successful ETL.
      # 步骤 2: ETL 成功后，运行 Crawler 更新元数据
      "RunCrawler" = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = aws_glue_crawler.etl_crawler.name
        }
        Next = "NotifySuccess"
      }

      # Step 3 (Success Path): Send completion notification.
      # 步骤 3 (成功路径): 发送完成通知
      "NotifySuccess" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "SUCCESS: Data Platform ETL Pipeline completed successfully. Data is now available in Athena."
        }
        End = true
      }

      # Step 3 (Failure Path): Send failure alert.
      # 步骤 3 (失败路径): 发送失败报警
      "NotifyFailure" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "ALERT: Glue ETL Job failed in the Step Functions pipeline. Check CloudWatch logs for details."
        }
        End = true
      }
    }
  })
}

# 3. Scheduled Trigger (EventBridge Scheduler)
# Centralized scheduling managed by EventBridge triggers, replacing scattered Glue Triggers.
# 3. 定时调度 (EventBridge Scheduler)
# 替代原本分散在 Glue Trigger 里的定时逻辑，统一由 EventBridge 触发 SFN
resource "aws_cloudwatch_event_rule" "etl_schedule" {
  name                = "${var.project_name}-${var.environment}-etl-schedule"
  description         = "Trigger ETL Step Functions Pipeline daily"
  schedule_expression = var.glue_trigger_schedule
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "trigger_sfn" {
  rule      = aws_cloudwatch_event_rule.etl_schedule.name
  target_id = "TriggerSFN"
  arn       = aws_sfn_state_machine.etl_pipeline.arn
  role_arn  = aws_iam_role.eventbridge_sfn_role.arn
}

# IAM Role specifically for EventBridge to trigger SFN.
# 专门给 EventBridge 用来触发 SFN 的 IAM Role
resource "aws_iam_role" "eventbridge_sfn_role" {
  name = "${var.project_name}-${var.environment}-eb-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "eb_sfn_policy" {
  name = "eb-sfn-policy"
  role = aws_iam_role.eventbridge_sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["states:StartExecution"]
      Resource = aws_sfn_state_machine.etl_pipeline.arn
    }]
  })
}
