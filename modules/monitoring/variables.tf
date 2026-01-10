variable "project_name" {
  # Project name.
  # 项目名称。
  description = "Project name"
  type        = string
}

variable "environment" {
  # Environment (dev/prod).
  # 环境 (dev/prod)。
  description = "Environment (dev/prod)"
  type        = string
}

variable "alert_email" {
  # Email address to receive alerts.
  # 接收报警的邮箱地址。
  description = "Email address to receive alerts"
  type        = string
}