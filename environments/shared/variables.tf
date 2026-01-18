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

variable "layer" {
  description = "Infrastructure layer identifier (e.g., shared, network)"
  type        = string
  default     = "shared"
}

variable "environment" {
  description = "Environment context (default to shared for this layer)"
  type        = string
  default     = "dev"
}