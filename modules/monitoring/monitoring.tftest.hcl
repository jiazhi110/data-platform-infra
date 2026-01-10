# ------------------------------------------------------------------------------
# Terraform Native Test - Monitoring Module
# ------------------------------------------------------------------------------

# Inject a temporary AWS Provider configuration for the test environment.
# 为测试环境注入一个临时的 AWS Provider 配置
provider "aws" {
  region = "us-east-1"
}

# 1. Set input variables for testing.
# 1. 设置测试用的输入变量
variables {
  project_name = "unit-test"
  environment  = "sandbox"
  alert_email  = "test@example.com"
}

# 2. Test Case 1: Verify SNS Topic Name
# We use 'command = plan', meaning the test runs without creating real resources.
# 2. 第一个测试用例：验证 SNS Topic 的名字
# 我们使用 'command = plan'，这意味着测试会在不创建真实资源的情况下运行。
run "verify_sns_topic_name" {
  command = plan

  assert {
    condition     = aws_sns_topic.alerts.name == "unit-test-sandbox-alerts-topic"
    error_message = "SNS topic name does not match the mandatory kebab-case format: <project>-<env>-alerts-topic"
  }
}

# 3. Test Case 2: Verify Email Subscription Endpoint
# 3. 第二个测试用例：验证邮件订阅端点
run "verify_email_subscription" {
  command = plan

  assert {
    condition     = aws_sns_topic_subscription.email_subscription.endpoint == "test@example.com"
    error_message = "The SNS email subscription endpoint was not passed correctly from the variables."
  }
}