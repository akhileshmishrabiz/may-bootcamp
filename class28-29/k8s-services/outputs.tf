# Load Balancer Controller Outputs
output "load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}

output "load_balancer_controller_installed" {
  description = "Status of AWS Load Balancer Controller installation"
  value       = helm_release.aws_load_balancer_controller.status
}
