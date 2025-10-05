# EKS Infrastructure with Terraform

Production-ready EKS cluster with NGINX Ingress, cert-manager, RDS PostgreSQL, and ArgoCD GitOps.

## Overview

Complete Kubernetes infrastructure on AWS with:
- **EKS Cluster** (Kubernetes 1.31) with managed node groups
- **VPC** with public/private subnets across 3 AZs
- **RDS PostgreSQL** database (encrypted, automated backups)
- **NGINX Ingress** + Network Load Balancer
- **cert-manager** for automatic TLS (Let's Encrypt)
- **Route53** DNS with wildcard records
- **ArgoCD** for GitOps continuous deployment

## Architecture

```
Internet → Route53 (*.ms1.akhileshmishra.tech) → NLB → NGINX Ingress
    |
    +-- Frontend (ms1.akhileshmishra.tech)
    +-- Catalogue (catalogue.ms1.akhileshmishra.tech)
    +-- Voting (voting.ms1.akhileshmishra.tech)
    +-- Recommendations (recommendations.ms1.akhileshmishra.tech)
    +-- ArgoCD (argocd.ms1.akhileshmishra.tech)
    |
    v
EKS Pods (Private Subnets) → RDS PostgreSQL (Private Subnets)
```

## Microservices Routing Strategy

### Why Subdomains Instead of Paths?

This infrastructure uses **subdomain-based routing** (e.g., `api.example.com`, `auth.example.com`) instead of **path-based routing** (e.g., `example.com/api`, `example.com/auth`).

**Subdomain Approach Benefits:**
- **Cookie isolation**: No cookie leakage between services (security)
- **Independent scaling**: Each service can be moved/scaled independently
- **Team ownership**: Different teams own different subdomains
- **Better caching**: Independent CDN/caching policies per service
- **DNS-level load balancing**: Distribute traffic at DNS layer

**Path-based Drawbacks:**
- Cookie sharing across all paths (security risk)
- Path conflicts between services
- Tight coupling - harder to refactor
- Single ingress point (bottleneck)

**Real-world Standard:**
- **Large companies**: Full subdomain isolation per service
- **Startups**: Hybrid (`example.com` + `api.example.com/*`)
- **This project**: Full subdomain isolation with wildcard TLS cert

**HTTPS Everywhere:**
- All endpoints use HTTPS (industry standard)
- Let's Encrypt wildcard cert (`*.ms1.akhileshmishra.tech`) covers all subdomains
- cert-manager handles automatic renewal
- Zero manual certificate management

## Key Components

| Component | Purpose | Implementation |
|-----------|---------|----------------|
| **VPC** | Network isolation | 10.0.0.0/16 with public/private subnets across 3 AZs |
| **EKS** | Kubernetes cluster | v1.31, managed node groups (t3.medium, 2-3 nodes) |
| **RDS** | PostgreSQL database | v14.15, encrypted, automated backups, private subnets |
| **NGINX Ingress** | Traffic routing | NLB backend, subdomain-based routing, TLS termination |
| **cert-manager** | TLS certificates | Let's Encrypt wildcard cert, auto-renewal |
| **Route53** | DNS management | Wildcard record `*.ms1.akhileshmishra.tech` |
| **ArgoCD** | GitOps | Continuous deployment from Git repository |
| **IAM (IRSA)** | Permissions | Service accounts for LB controller & cert-manager |

## Prerequisites

- **AWS CLI** configured
- **Terraform** >= 1.5.0
- **kubectl** installed
- **Route53 Hosted Zone** for your domain
- **S3 Bucket** for Terraform state

## Deployment

```bash
# 1. Initialize
terraform init

# 2. Plan
terraform plan

# 3. Apply (takes 15-20 minutes)
terraform apply

# 4. Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name may25-dev-cluster

# 5. Verify deployment
kubectl get nodes
kubectl get certificate -n craftista
kubectl get ingress -n craftista

# 6. Test endpoints
curl -I https://ms1.akhileshmishra.tech
curl -I https://argocd.ms1.akhileshmishra.tech
```

## Implementation Approach

### 1. Network Layer (network.tf)
- VPC with public/private subnet isolation
- Single NAT Gateway (cost optimized)
- Security groups for controlled access

### 2. Compute Layer (eks.tf)
- EKS managed node groups in private subnets
- Auto-scaling (1-3 nodes)
- Public API endpoint for kubectl access

### 3. Data Layer (rds.tf)
- PostgreSQL in private subnets (isolated)
- KMS encryption at rest
- Credentials auto-generated and stored in Secrets Manager

### 4. Ingress Layer (helm.tf + cert.tf)
- NLB → NGINX Ingress → Services
- Subdomain-based routing for service isolation
- Automatic TLS via cert-manager

### 5. GitOps Layer (argocd.tf)
- ArgoCD monitors Git repository
- Auto-sync on changes
- Self-healing (reverts manual changes)

### 6. IAM Security (iam.tf)
- IRSA (IAM Roles for Service Accounts)
- No long-lived credentials
- Principle of least privilege

## ArgoCD GitOps

**Access:** https://argocd.ms1.akhileshmishra.tech

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### GitOps Workflow

1. **Developer pushes code** to Git repository
2. **ArgoCD detects change** (polls every 3 minutes)
3. **Auto-sync applies changes** to cluster
4. **Self-healing** reverts any manual changes

```bash
# Example: Update application version
cd class28-29/microservices-on-k8s/k8s-menifest-adv
# Edit deployment.yaml: image: v1.0 → v2.0
git commit -am "Update to v2.0" && git push
# ArgoCD automatically deploys within 3 minutes
```

### Deployment Strategies Comparison

| Strategy | Downtime | Complexity | Use Case |
|----------|----------|------------|----------|
| **Rolling Update** | None | Low | Default, most applications |
| **Blue/Green** | None | Medium | Critical apps, instant rollback needed |
| **Canary** | None | High | Risky changes, gradual traffic shift |
| **Feature Flags** | None | High | SaaS apps, A/B testing |

### Rollback

```bash
# Option 1: Git revert (recommended)
git revert HEAD && git push

# Option 2: ArgoCD UI
# Application → History → Select revision → Rollback
```

## Security Features

- **RDS**: KMS encryption, private subnets, auto-generated passwords
- **Network**: Private EKS nodes, NAT gateway, security groups
- **IAM**: IRSA (no long-lived credentials), least privilege
- **TLS**: Automatic certificate management, SSL redirect enforced

## Cost Optimization

**Monthly estimate: ~$150-200**
- Single NAT Gateway (~$32/month)
- t3.medium nodes (2 instances)
- db.t3.micro RDS
- gp3 storage (cheaper than gp2)
- NLB (cheaper than ALB)

## Troubleshooting

```bash
# Certificate issues
kubectl describe certificate craftista-tls-cert -n craftista
kubectl logs -n cert-manager -l app=cert-manager

# Ingress issues
kubectl describe ingress craftista-ingress -n craftista
kubectl get svc -n ingress-nginx

# ArgoCD sync issues
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# Node group stuck: Add vpc-cni addon manually in AWS Console
```

## Cleanup

```bash
# Delete Kubernetes resources first
kubectl delete ingress craftista-ingress -n craftista
kubectl delete certificate craftista-tls-cert -n craftista

# Destroy infrastructure
terraform destroy
```

## References

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [cert-manager Documentation](https://cert-manager.io/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

**Last Updated**: 2025-10-05 | **Terraform**: >= 1.5.0 | **Kubernetes**: 1.31
