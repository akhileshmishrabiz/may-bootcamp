variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "devopsbootcamp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "prefix" {
  description = "Prefix to be used for all resources"
  type        = string
  default     = "may25"
}
