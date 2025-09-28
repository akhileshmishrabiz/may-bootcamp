resource "aws_cloudwatch_log_group" "rds_migration" {
  name              = "/aws/ecs/${var.environment}-rds-migration-${var.batch}"
  retention_in_days = 7
}

resource "aws_cloudwatch_query_definition" "rds_migration_logs" {
  name = "${var.environment}${var.batch}/rds-migration"

  log_group_names = [
    aws_cloudwatch_log_group.rds_migration.name,
  ]

  query_string = <<EOF
filter @message not like /.+Waiting.+/
| fields @timestamp, @message
| sort @timestamp desc
| limit 200
EOF
}