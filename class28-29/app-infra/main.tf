# Data sources to get VPC information from base-eks-infra
data "aws_vpc" "eks_vpc" {
  tags = {
    Name = "${var.prefix}-${var.environment}-vpc"
  }
}

# Data sources to get EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = "${var.prefix}-${var.environment}-cluster"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "${var.prefix}-${var.environment}-cluster"
}

# RDS Subnets
resource "aws_subnet" "rds_1" {
  cidr_block        = "10.0.5.0/24"
  availability_zone = "ap-south-1a"
  vpc_id            = data.aws_vpc.eks_vpc.id

  tags = {
    Name = "RDS Private Subnet 1"
  }
}

resource "aws_subnet" "rds_2" {
  cidr_block        = "10.0.6.0/24"
  availability_zone = "ap-south-1b"
  vpc_id            = data.aws_vpc.eks_vpc.id

  tags = {
    Name = "RDS Private Subnet 2"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.environment}-rds-sg"
  vpc_id      = data.aws_vpc.eks_vpc.id
  description = "allow inbound access from the ECS only"

  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    cidr_blocks     = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# KMS Key for encryption
resource "aws_kms_key" "env_kms" {
  description             = "KMS key for RDS and Secrets Manager"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.prefix}-${var.environment}-rds-kms-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "env_kms_alias" {
  name          = "alias/${var.environment}-rds-eks-kms-key"
  target_key_id = aws_kms_key.env_kms.id
}

# DB Subnet Group
resource "aws_db_subnet_group" "postgres" {
  name        = "${var.prefix}-${var.environment}-rds-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids = [
    aws_subnet.rds_1.id,
    aws_subnet.rds_2.id
  ]

  tags = {
    Name        = "${var.prefix}-${var.environment}-db-subnet-group"
    Environment = var.environment
  }
}

# Random password for DB
resource "random_password" "dbs_random_string" {
  length           = 10
  special          = false
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier            = "${var.prefix}-db"
  allocated_storage     = var.db_default_settings.allocated_storage
  max_allocated_storage = var.db_default_settings.max_allocated_storage
  engine                = "postgres"
  engine_version        = 14.15
  instance_class        = var.db_default_settings.instance_class
  username              = var.db_default_settings.db_admin_username
  password              = random_password.dbs_random_string.result
  port                  = 5432
  publicly_accessible   = false
  db_subnet_group_name  = aws_db_subnet_group.postgres.id
  ca_cert_identifier    = var.db_default_settings.ca_cert_name
  storage_encrypted     = true
  storage_type          = "gp3"
  kms_key_id            = aws_kms_key.env_kms.arn
  skip_final_snapshot   = true
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  backup_retention_period    = var.db_default_settings.backup_retention_period
  db_name                    = var.db_default_settings.db_name
  auto_minor_version_upgrade = true
  deletion_protection        = false
  copy_tags_to_snapshot      = true

  tags = {
    environment = var.environment
  }
}

# Secrets Manager for DB connection string
resource "aws_secretsmanager_secret" "db_link" {
  name                    = "db/${aws_db_instance.postgres.identifier}"
  description             = "DB link"
  kms_key_id              = aws_kms_key.env_kms.arn
  recovery_window_in_days = 7
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "dbs_secret_val" {
  secret_id     = aws_secretsmanager_secret.db_link.id
  secret_string = "postgresql://${var.db_default_settings.db_admin_username}:${random_password.dbs_random_string.result}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"

  lifecycle {
    create_before_destroy = true
  }
}

# Kubernetes Secret for Database Credentials
resource "kubernetes_secret" "catalogue_db_secrets" {
  metadata {
    name      = "catalogue-db-secrets"
    namespace = var.craft_namespace

    labels = {
      app         = "catalogue-service"
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  type = "Opaque"

  # Database credentials (will be mounted as files in /app/secrets/)
  data = {
    db_user     = aws_db_instance.postgres.username  # Creates file: /app/secrets/db_user
    db_password = random_password.dbs_random_string.result   # Creates file: /app/secrets/db_password
  }
}

# ConfigMap for Application Configuration
resource "kubernetes_config_map" "catalogue_config" {
  metadata {
    name      = "catalogue-config"
    namespace = var.craft_namespace

    labels = {
      app         = "catalogue-service"
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  data = {
    # App version as top-level key for environment variable
    app_version = "1.0.0"

    # This will be mounted as /app/config.json
    "config.json" = jsonencode({
      app_version = "1.0.0"
      data_source = "db"
      db_host     = aws_db_instance.postgres.address
      db_name     = aws_db_instance.postgres.db_name
      db_user     = aws_db_instance.postgres.username
      db_password = "placeholder"  # Will be overridden by secret volume
    })

    # This will be mounted as /app/db-config/db-config.properties
    "db-config.properties" = <<-EOT
      db_name=${aws_db_instance.postgres.db_name}
      db_host=${aws_db_instance.postgres.address}
    EOT
  }
}
