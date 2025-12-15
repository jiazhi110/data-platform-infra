variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/prod)"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive alerts"
  type        = string
}
