# task definition

resource "aws_ecs_task_definition" "rds_migration" {
  #checkov:skip=CKV_AWS_336: The ECS task needs write access to system
  family     = "${var.environment}-rds-migration"
  depends_on = [null_resource.ecr_image]
  container_definitions = jsonencode(
    [
      {
        "name" : "rds-migration",
        "image" : "${local.repository}:${local.tag}",
        "essential" : true,
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : aws_cloudwatch_log_group.rds_migration.name,
            "awslogs-region" : data.aws_region.current.name,
            "awslogs-stream-prefix" : "ecs"
          },
        },
        "environment" : [
          {
            "name" : "SG_ID",
            "value" : aws_security_group.rds_migration_sg.id
          },
          {
            "name" : "ENVIRONMENT",
            "value" : var.environment
          },
        ]
      }
  ])

  cpu = var.gpg_runner_sizes.cpu
  # role for task to pull the ecr image
  execution_role_arn = aws_iam_role.rds_migration_ecs_execution_role.arn
  memory             = var.gpg_runner_sizes.memory
  network_mode       = "awsvpc"
  requires_compatibilities = [
    "FARGATE",
  ]
  # role to allow th container to fetch the data from rds, and create rds 
  task_role_arn = aws_iam_role.rds_migration_ecs_task_role.arn

  # ecs iam role 
  # ecs execution role
  # ecs task role

  ephemeral_storage {
    size_in_gib = 30
  }
}

# ecs cluster

resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.environment}rds-migration-${var.batch}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "rds_migration_sg" {
  #checkov:skip=CKV2_AWS_5: Will be attached
  name        = "${var.environment}-rds-shrink"
  vpc_id      = data.aws_vpc.default.id
  description = "SG for ECS-rds-shrink"

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Access to AWS API"
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${var.environment}-rds-shrink"
  }
}
