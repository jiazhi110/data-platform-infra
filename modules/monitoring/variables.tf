variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "alert_email" {
  description = "Target email for alert notifications"
  type        = string
}
