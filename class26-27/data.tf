data "aws_ecr_authorization_token" "token" {}

data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_kms_key" "rds_kms" {
  key_id = "alias/dev-rds-kms-key"
}

data "aws_subnets" "default" {
    filter {
        name   = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}
