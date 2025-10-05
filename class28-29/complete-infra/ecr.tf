resource "aws_ecr_repository" "frontend" {
  name = "${var.project_name}-${var.environment}-frontend"
}

resource "aws_ecr_repository" "catalogue" {
  name = "${var.project_name}-${var.environment}-catalogue"
}

resource "aws_ecr_repository" "voting" {
  name = "${var.project_name}-${var.environment}-voting"
}

resource "aws_ecr_repository" "recommendations" {
  name = "${var.project_name}-${var.environment}-recommendations"
}
