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

variable "db_default_settings" {
  type = any
  default = {
    allocated_storage       = 30
    max_allocated_storage   = 50
    engine_version          = 14.15
    instance_class          = "db.t3.micro"
    backup_retention_period = 2
    db_name                 = "postgres"
    ca_cert_name            = "rds-ca-rsa2048-g1"
    db_admin_username       = "postgres"
  }
}


variable "craft_namespace" {
  description = "Craftista Namespace"
  type        = string
  default     = "craftista"
}

# Certificate management variables
variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "devops-may-cluster"
}

variable "domain_name" {
  description = "The root domain name"
  type        = string
  default     = "akhileshmishra.tech"
}

variable "subdomain" {
  description = "The subdomain prefix"
  type        = string
  default     = "ms1"
}

variable "namespace" {
  description = "Kubernetes namespace for the application"
  type        = string
  default     = "craftista"
}

variable "cert_email" {
  description = "Email address for Let's Encrypt certificate registration"
  type        = string
  default     = "admin@akhileshmishra.tech"
}

variable "application_name" {
  description = "Application name for tagging"
  type        = string
  default     = "craftista"
  
}

