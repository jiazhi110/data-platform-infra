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
    Comment         = "Production-grade Glue ETL Orchestration with Result Validation"
    StartAt         = "HasManualOverrides"
    States = {
      "HasManualOverrides" = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.process_date"
            IsPresent = true
            Next = "RunETLJobWithOverrides"
          }
        ]
        Default = "RunETLJob"
      }

      # Step 1: Run Glue ETL Job (Synchronous)
      "RunETLJob" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync" 
        Parameters = {
          JobName = aws_glue_job.top_produce_etl_job.name
          Arguments = {
            "--process_date.$" = "States.ArrayGetItem(States.StringSplit($$.Execution.StartTime, 'T'), 0)"
            "--is_backfill"    = "false"
          }
        }
        Retry = [{
          ErrorEquals     = ["Glue.AWSGlueException", "States.TaskFailed"],
          IntervalSeconds = 60,
          MaxAttempts     = 3,
          BackoffRate     = 2.0
        }]
        Next = "RunCrawler"
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "NotifyFailure"
        }]
      }

      "RunETLJobWithOverrides" = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = {
          JobName = aws_glue_job.top_produce_etl_job.name
          Arguments = {
            "--process_date.$" = "$.process_date"
            "--is_backfill.$"  = "$.is_backfill"
          }
        }
        Retry = [{
          ErrorEquals     = ["Glue.AWSGlueException", "States.TaskFailed"],
          IntervalSeconds = 60,
          MaxAttempts     = 3,
          BackoffRate     = 2.0
        }]
        Next = "RunCrawler"
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "NotifyFailure"
        }]
      }

      # Step 2: Start Glue Crawler
      "RunCrawler" = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = aws_glue_crawler.etl_crawler.name
        }
        # Retry for Transient API errors (Throttling, etc.)
        Retry = [{
          ErrorEquals     = ["States.ALL"],
          IntervalSeconds = 5,
          MaxAttempts     = 3,
          BackoffRate     = 2.0
        }]
        Next = "WaitCrawler"
        Catch = [{
          ErrorEquals = ["States.ALL"],
          Next        = "NotifyFailure"
        }]
      }

      "WaitCrawler" = {
        Type    = "Wait"
        Seconds = 30
        Next    = "GetCrawlerStatus"
      }

      "GetCrawlerStatus" = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler"
        Parameters = {
          Name = aws_glue_crawler.etl_crawler.name
        }
        Retry = [{
          ErrorEquals     = ["States.ALL"],
          IntervalSeconds = 2,
          MaxAttempts     = 3
        }]
        Next = "CheckCrawlerState"
      }

      # Step 3: Check if Crawler finished its cycle
      "CheckCrawlerState" = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.Crawler.State"
            StringEquals = "RUNNING"
            Next         = "WaitCrawler"
          },
          {
            Variable     = "$.Crawler.State"
            StringEquals = "STOPPING"
            Next         = "WaitCrawler"
          },
          {
            Variable     = "$.Crawler.State"
            StringEquals = "READY"
            Next         = "CheckCrawlOutcome" # Proceed to outcome validation
          }
        ]
        Default = "NotifyFailure"
      }

      # Step 4: Validate the actual outcome (Senior Best Practice)
      # Ensures we don't report Success if the Crawler finished but failed internally.
      "CheckCrawlOutcome" = {
        Type = "Choice"
        Choices = [
          {
            Variable     = "$.Crawler.LastCrawl.Status"
            StringEquals = "SUCCEEDED"
            Next         = "NotifySuccess"
          }
        ]
        Default = "NotifyFailure"
      }

      "NotifySuccess" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "SUCCESS: ETL Pipeline completed. Data is now searchable in Athena."
        }
        End = true
      }

      "NotifyFailure" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          TopicArn = var.sns_alert_topic_arn
          Message  = "ALERT: ETL Pipeline FAILED. Please check Step Functions execution log or Glue Job CloudWatch logs."
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
