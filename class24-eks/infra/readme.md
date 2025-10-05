# EKS Infrastructure with Terraform

Production-ready EKS cluster with AWS Load Balancer Controller, ACM certificates, and RDS PostgreSQL.

## Overview

Complete Kubernetes infrastructure on AWS with:
- **EKS Cluster** (Kubernetes 1.31) with managed node groups
- **AWS Load Balancer Controller** for native ALB/NLB management
- **ACM Certificates** for automatic HTTPS (managed by AWS)
- **RDS PostgreSQL** database (encrypted, automated backups)
- **Route53 DNS** with wildcard subdomain mapping
- **Application Load Balancer (ALB)** for HTTP/HTTPS traffic

## Architecture

```
Internet → Route53 (*.ms.akhileshmishra.tech) → ALB (ACM cert) → EKS Services
    |
    +-- Main App (ms.akhileshmishra.tech)
    +-- Catalogue (catalogue.ms.akhileshmishra.tech)
    +-- Voting (voting.ms.akhileshmishra.tech)
    +-- Recommendations (recommendations.ms.akhileshmishra.tech)
    |
    v
EKS Pods (Private Subnets) → RDS PostgreSQL (Private Subnets)
```

## Microservices Routing Strategy

### Why Subdomains Instead of Paths?

This infrastructure uses **subdomain-based routing** for each microservice.

**Benefits:**
- **Cookie isolation**: No cookie leakage between services
- **Independent scaling**: Each service can scale independently
- **Team ownership**: Different teams can own different subdomains
- **Better caching**: Independent CDN/caching policies
- **DNS-level routing**: Can distribute traffic at DNS layer

**Real-world Usage:**
- **Large companies**: Full subdomain isolation per service
- **Startups**: Hybrid approach (`example.com` + `api.example.com/*`)
- **This project**: Full subdomain isolation

## SSL/TLS Certificate Coverage

### ACM Wildcard Certificate

**Single certificate covers ALL subdomains:**
- ✅ `ms.akhileshmishra.tech` (base domain)
- ✅ `catalogue.ms.akhileshmishra.tech`
- ✅ `voting.ms.akhileshmishra.tech`
- ✅ `recommendations.ms.akhileshmishra.tech`
- ✅ Any future subdomain: `*.ms.akhileshmishra.tech`

**How it works:**
1. **ACM creates wildcard cert**: `*.ms.akhileshmishra.tech` + `ms.akhileshmishra.tech`
2. **DNS validation**: Automatic via Route53 (no manual steps)
3. **ALB attachment**: Certificate automatically attached to ALB
4. **Auto-renewal**: AWS handles renewal automatically (no expiration)

**All endpoints use HTTPS automatically** - no additional configuration needed per service.

### ACM vs Let's Encrypt Comparison

| Feature | ACM (This Project) | Let's Encrypt (class28-29) |
|---------|-------------------|---------------------------|
| **Cost** | Free (AWS managed) | Free (open source) |
| **Renewal** | Automatic (no expiration) | Every 90 days (auto via cert-manager) |
| **Validation** | DNS (Route53) | HTTP-01 or DNS-01 |
| **Management** | AWS Console/API | cert-manager in cluster |
| **Portability** | AWS only | Cloud-agnostic |
| **Setup** | Simpler (native AWS) | More complex (external tool) |
| **Best for** | AWS-only deployments | Multi-cloud, on-prem |

## Prerequisites

- **AWS CLI** configured
- **Terraform** >= 1.0
- **kubectl** installed
- **Route53 Hosted Zone** for your domain

## Deployment

```bash
# 1. Initialize
terraform init

# 2. Plan
terraform plan

# 3. Apply (takes 15-20 minutes)
terraform apply

# Note: If stuck on node group creation, manually add VPC-CNI addon in AWS Console

# 4. Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name may25-dev-cluster

# 5. Verify deployment
kubectl get nodes
kubectl get ingress -n craftista
aws acm list-certificates --region ap-south-1

# 6. Test HTTPS endpoints
curl -I https://ms.akhileshmishra.tech
curl -I https://catalogue.ms.akhileshmishra.tech
```

## Implementation Components

| Component | File | Purpose |
|-----------|------|---------|
| **VPC & Networking** | network.tf | Public/private subnets, NAT gateway |
| **EKS Cluster** | eks.tf | Kubernetes control plane, node groups |
| **Load Balancer** | helm.tf | AWS LB Controller for ALB/NLB |
| **Certificates** | cert.tf | ACM wildcard cert, ingress configuration |
| **Database** | rds.tf | PostgreSQL with KMS encryption |
| **IAM** | iam.tf | IRSA for LB controller |
| **Kubernetes** | k8s.tf | Namespaces, secrets, configmaps |

## Key Differences: ALB vs NLB Approach

This project uses **ALB (Application Load Balancer)** instead of **NLB + NGINX Ingress** (used in class28-29).

| Feature | ALB (This Project) | NLB + NGINX (class28-29) |
|---------|-------------------|-------------------------|
| **Layer** | Layer 7 (HTTP/HTTPS) | Layer 4 (TCP) + Layer 7 (NGINX) |
| **TLS Termination** | At ALB (ACM cert) | At NGINX (Let's Encrypt) |
| **Routing** | ALB rules | NGINX Ingress rules |
| **Health Checks** | HTTP/HTTPS | TCP/HTTP |
| **Cost** | ~$20/month | ~$18/month (NLB) |
| **Flexibility** | AWS-specific | Cloud-agnostic |
| **WebSockets** | Supported | Better support |
| **Best for** | AWS-native, HTTP/HTTPS only | Multi-cloud, advanced routing |

## Security Features

- **ACM Certificates**: Automatic HTTPS for all subdomains
- **RDS**: KMS encryption, private subnets, auto-generated passwords
- **Network**: Private EKS nodes, NAT gateway, security groups
- **IAM**: IRSA (no long-lived credentials), least privilege

## Troubleshooting

```bash
# Check ALB creation
kubectl describe ingress -n craftista

# Check AWS LB Controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check ACM certificate status
aws acm describe-certificate --certificate-arn <arn>

# Node group stuck: Add vpc-cni addon manually in AWS Console
```

## Cleanup

```bash
# Delete Kubernetes ingress first
kubectl delete ingress -n craftista --all

# Destroy infrastructure
terraform destroy
```

---

**Last Updated**: 2025-10-05 | **Terraform**: >= 1.0 | **Kubernetes**: 1.31
