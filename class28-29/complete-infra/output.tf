# ============================================================================
# Monitoring Stack Outputs
# ============================================================================

output "grafana_url" {
  description = "URL to access Grafana dashboard"
  value       = "https://${var.subdomain}.${var.domain_name}/grafana"
}

output "grafana_admin_password" {
  description = "Grafana admin password (change this in production!)"
  value       = "admin123"
  sensitive   = true
}

output "prometheus_url" {
  description = "URL to access Prometheus dashboard"
  value       = "https://${var.subdomain}.${var.domain_name}/prometheus"
}

output "monitoring_namespace" {
  description = "Kubernetes namespace for monitoring stack"
  value       = "monitoring"
}

# ============================================================================
# EKS Cluster Outputs
# ============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_region" {
  description = "AWS region where the cluster is deployed"
  value       = var.aws_region
}

# ============================================================================
# Database Outputs
# ============================================================================

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

# ============================================================================
# Application Outputs
# ============================================================================

output "application_namespace" {
  description = "Kubernetes namespace for Craftista application"
  value       = var.craft_namespace
}

output "application_domain" {
  description = "Application domain"
  value       = "${var.subdomain}.${var.domain_name}"
}
