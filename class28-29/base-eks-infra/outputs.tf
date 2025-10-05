# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.eks_network.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.eks_network.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.eks_network.public_subnets
}

# EKS Outputs
output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}
