variable "project_name" {
  description = "Project name"
  type        = string
  default     = "data-platform"
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier (e.g., shared, tools)"
  type        = string
  default     = "shared"
}