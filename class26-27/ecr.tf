resource "aws_ecr_repository" "rds_migration" {
  name = "${var.environment}-rds-migration-${var.batch}"
}

