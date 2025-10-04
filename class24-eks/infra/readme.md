# EKS Infrastructure with Terraform

## Overview
This Terraform configuration deploys an EKS cluster with the following components:
- **EKS Cluster** (v1.31) with managed node groups
- **AWS Load Balancer Controller** for ingress management
- **ACM Certificates** for HTTPS (replaces Let's Encrypt)
- **RDS PostgreSQL** database
- **Route53 DNS** with wildcard subdomain mapping
- **Craftista microservices** infrastructure

## Architecture
- **Ingress**: AWS Application Load Balancer (ALB) with ACM certificates
- **TLS/SSL**: AWS Certificate Manager (ACM) with DNS validation via Route53
- **DNS**: Wildcard record `*.ms.akhileshmishra.tech` → ALB
- **Applications**:
  - Main app: `ms.akhileshmishra.tech`
  - Catalogue: `catalogue.ms.akhileshmishra.tech`
  - Voting: `voting.ms.akhileshmishra.tech`
  - Recommendations: `recommendations.ms.akhileshmishra.tech`

## Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl
- A Route53 hosted zone for your domain

## Deployment

### 1. Initialize Terraform
```bash
terraform init
```

### 2. Plan Infrastructure
```bash
terraform plan
```

### 3. Deploy Infrastructure
```bash
terraform apply
```

**Note**: First apply may get stuck on managed node group creation:
- Manually add the VPC-CNI addon in AWS Console/CLI
- The apply will then complete successfully

### 4. Configure Cluster Access
```bash
aws eks update-kubeconfig --region ap-south-1 --name may25-dev-cluster
```

### 5. Verify Resources
```bash
# Check nodes
kubectl get nodes

# Check AWS LB Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Check ingress
kubectl get ingress -n craftista

# Check ACM certificates
aws acm list-certificates --region ap-south-1
```

## Key Files
- `eks.tf` - EKS cluster configuration
- `cert.tf` - ACM certificates and ingress setup
- `iam.tf` - IAM roles for AWS Load Balancer Controller
- `helm.tf` - AWS Load Balancer Controller helm deployment
- `rds.tf` - PostgreSQL database
- `network.tf` - VPC and networking
- `k8s.tf` - Kubernetes namespace and secrets
- `argocd.tf` - ArgoCD setup (currently commented out)

## Certificate Management
This setup uses **AWS Certificate Manager (ACM)** instead of Let's Encrypt:
- Certificates are automatically validated via Route53 DNS
- ACM certificates are referenced in ALB ingress annotations
- No cert-manager required

## DNS Configuration
- Base domain: `akhileshmishra.tech`
- Subdomain: `ms.akhileshmishra.tech`
- Wildcard: `*.ms.akhileshmishra.tech` → Points to ALB

## Outputs
After deployment, Terraform outputs include:
- VPC ID
- EKS cluster endpoint
- Database endpoint
- Route53 records

## Clean Up
```bash
terraform destroy
```

**Warning**: This will delete all resources including the database. Ensure you have backups if needed.
