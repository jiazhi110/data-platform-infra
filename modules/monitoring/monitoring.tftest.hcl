# ------------------------------------------------------------------------------
# Terraform Native Test - Monitoring Module
# ------------------------------------------------------------------------------

# Temporary provider for module unit testing.
provider "aws" {
  region = "us-east-1"
}

# Test input variables.
variables {
  project_name = "unit-test"
  environment  = "sandbox"
  alert_email  = "test@example.com"
}

# Test Case 1: Verify SNS Topic naming convention.
run "verify_sns_topic_name" {
  command = plan

  assert {
    condition     = aws_sns_topic.alerts.name == "unit-test-sandbox-alerts-topic"
    error_message = "SNS topic name does not match the mandatory format: <project>-<env>-alerts-topic"
  }
}

# Test Case 2: Verify Email Subscription endpoint configuration.
run "verify_email_subscription" {
  command = plan

  assert {
    condition     = aws_sns_topic_subscription.email_subscription.endpoint == "test@example.com"
    error_message = "SNS email subscription endpoint mismatch."
  }
}
