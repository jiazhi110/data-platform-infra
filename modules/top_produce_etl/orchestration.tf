# --- AWS Step Functions Orchestration ---
# Orchestrates Glue Jobs and Crawlers into a resilient, automated pipeline.

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

# IAM policy for SFN to manage Glue resources and publish alerts to SNS.
resource "aws_iam_role_policy" "sfn_policy" {
  name = "sfn-orchestration-policy"
  role = aws_iam_role.sfn_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:BatchStopJobRun"
        ]
        Resource = aws_glue_job.top_produce_etl_job.arn
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartCrawler",
          "glue:GetCrawler"
        ]
        Resource = aws_glue_crawler.etl_crawler.arn
      },
      {
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
resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "${var.project_name}-${var.environment}-etl-workflow"
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Orchestrates Glue ETL Job and Crawler with Error Handling"
    StartAt = "RunETLJob"
    States = {
      # Step 1: Run Glue ETL Job. 
      # .sync pattern waits for job completion before proceeding.
      "RunETLJob" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync" 
        Parameters = {
          JobName = aws_glue_job.top_produce_etl_job.name
        }
        # Retry Strategy: Exponential backoff for AWS service exceptions.
        Retry = [{
          ErrorEquals     = ["Glue.AWSGlueException", "States.TaskFailed"],
          IntervalSeconds = 60,
          MaxAttempts     = 3,
          BackoffRate     = 2.0
        }]
        Next = "RunCrawler"
        # Catch Block: Notify failure via SNS if retries are exhausted.
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "NotifyFailure"
        }]
      }

      # Step 2: Update Metadata via Glue Crawler.
      "RunCrawler" = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = aws_glue_crawler.etl_crawler.name
        }
        Next = "NotifySuccess"
      }

      "NotifySuccess" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "SUCCESS: ETL Pipeline completed. Data available in Athena."
        }
        End = true
      }

      "NotifyFailure" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "ALERT: Glue ETL Job failed. Check CloudWatch logs for details."
        }
        End = true
      }
    }
  })
}

# 3. Scheduled Trigger (EventBridge)
# Centralized scheduling via EventBridge to trigger the Step Functions workflow.
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

# IAM Role for EventBridge to trigger Step Functions execution.
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