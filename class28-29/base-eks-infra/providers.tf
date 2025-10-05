provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      Terraform   = "true"
      Prefix      = var.prefix
      repo        = "may-bootcamp"
    }
  }
}
