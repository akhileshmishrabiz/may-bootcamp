# Craftista Microservices Deployment Guide

## Architecture Overview

This deployment uses a hybrid approach combining **Terraform for infrastructure** and **Kubernetes manifests for application deployment**, utilizing Let's Encrypt certificates with DNS-01 validation for SSL/TLS.

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Cloud                                │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                     Route53                               │  │
│  │  • ms.akhileshmishra.tech                                │  │
│  │  • *.ms.akhileshmishra.tech (wildcard)                   │  │
│  │        ↓                                                   │  │
│  └────────┼──────────────────────────────────────────────────┘  │
│           ↓                                                       │
│  ┌────────┼──────────────────────────────────────────────────┐  │
│  │        ↓         Application Load Balancer (ALB)          │  │
│  │  • Internet-facing                                         │  │
│  │  • SSL/TLS termination (Let's Encrypt)                    │  │
│  │  • Host-based routing                                     │  │
│  └────────┼──────────────────────────────────────────────────┘  │
│           ↓                                                       │
│  ┌────────┴──────────────────────────────────────────────────┐  │
│  │                  EKS Cluster                               │  │
│  │                                                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │  │
│  │  │   Frontend   │  │  Catalogue   │  │    Voting    │   │  │
│  │  │   (Node.js)  │  │   (Python)   │  │    (Java)    │   │  │
│  │  │   Port: 80   │  │  Port: 5000  │  │  Port: 8080  │   │  │
│  │  └──────────────┘  └──────┬───────┘  └──────┬───────┘   │  │
│  │                            │                  │            │  │
│  │  ┌──────────────┐         │                  │            │  │
│  │  │Recommendation│         │                  │            │  │
│  │  │    (Go)      │         │                  │            │  │
│  │  │  Port: 8080  │         │                  │            │  │
│  │  └──────────────┘         ↓                  ↓            │  │
│  │                     ┌──────────────────────────┐          │  │
│  │                     │     RDS PostgreSQL       │          │  │
│  │                     │  craftista-db.....       │          │  │
│  │                     └──────────────────────────┘          │  │
│  │                                                             │  │
│  │  ┌────────────────────────────────────────────────────┐   │  │
│  │  │           cert-manager (Helm)                      │   │  │
│  │  │  • ClusterIssuer (DNS-01 via Route53)             │   │  │
│  │  │  • Certificate (Let's Encrypt)                     │   │  │
│  │  │  • Auto-renewal every 90 days                      │   │  │
│  │  └────────────────────────────────────────────────────┘   │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

### 🏗️ Terraform Managed Resources (`/infra/`)

Terraform creates and manages the core infrastructure:

#### 1. **EKS Cluster** (`eks.tf`)
- Kubernetes control plane
- Worker nodes (EC2 or Fargate)
- VPC, Subnets, Security Groups
- AWS Load Balancer Controller (via Helm)

#### 2. **RDS PostgreSQL Database** (`rds.tf`)
- Database: `craftista-db`
- Endpoint: `craftista-db.cdglnjeympmt.ap-south-1.rds.amazonaws.com`
- Used by Catalogue and Voting services

#### 3. **Namespace** (`k8s.tf`)
```hcl
resource "kubernetes_namespace" "craftista"
```
- Creates `craftista` namespace for application resources

#### 4. **Secrets** (`k8s.tf`)
```hcl
resource "kubernetes_secret" "catalogue_db_secrets"
```
- Secret: `catalogue-db-secrets`
- Keys: `db_user`, `db_password`
- Mounted by Catalogue and Voting services

#### 5. **cert-manager** (`cert.tf`)
```hcl
resource "helm_release" "cert_manager"
```
- Helm chart version: v1.14.4
- Namespace: `cert-manager`
- Installs CRDs automatically
- IAM Role with Route53 permissions for DNS-01 challenge

#### 6. **ClusterIssuer** (`cert.tf`)
```hcl
resource "kubectl_manifest" "cluster_issuer"
```
- Name: `letsencrypt-prod`
- ACME Server: Let's Encrypt Production
- Solver: DNS-01 via Route53
- **Why DNS-01?** Avoids creating temporary NLBs (HTTP-01 would create 4 extra load balancers)

#### 7. **Certificate** (`cert.tf`)
```hcl
resource "kubectl_manifest" "craftista_certificate"
```
- Name: `craftista-tls-cert`
- Secret: `craftista-tls-secret`
- Domains:
  - `ms.akhileshmishra.tech`
  - `catalogue.ms.akhileshmishra.tech`
  - `voting.ms.akhileshmishra.tech`
  - `recommendations.ms.akhileshmishra.tech`

#### 8. **Ingress** (`cert.tf`)
```hcl
resource "kubernetes_ingress_v1" "craftista_ingress"
```
- Creates ALB via AWS Load Balancer Controller
- Annotations:
  - `alb.ingress.kubernetes.io/scheme: internet-facing`
  - `alb.ingress.kubernetes.io/target-type: ip`
  - `alb.ingress.kubernetes.io/listen-ports: HTTP(80) + HTTPS(443)`
  - `alb.ingress.kubernetes.io/ssl-redirect: 443`
- TLS: Uses `craftista-tls-secret` from cert-manager
- Host-based routing for each microservice

#### 9. **Route53 Records** (`cert.tf`)
```hcl
resource "aws_route53_record" "wildcard"
resource "aws_route53_record" "main"
```
- Wildcard: `*.ms.akhileshmishra.tech` → ALB
- Main: `ms.akhileshmishra.tech` → ALB
- **Wait Logic**:
  - `time_sleep.wait_for_alb` - 3 minute delay
  - `null_resource.check_alb` - Checks ALB existence every 30s (10 attempts)

### 📦 Kubernetes Manifests (`/k8s-menifest-adv/`)

Application deployment resources:

#### 1. **Namespace** (`01-namespace.yaml`)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: craftista
```
- Already created by Terraform, but safe to apply

#### 2. **Frontend Service** (`02-frontend-deployment.yaml`)
- **Deployment**: 2 replicas
- **Image**: `livingdevopswithakhilesh/microservices:frontend-*`
- **Port**: 3000 (exposed as 80)
- **Environment**:
  - `CATALOGUE_URL`: http://catalogue:5000
  - `RECOMMENDATION_URL`: http://recco:8080
  - `VOTING_URL`: http://voting:8080
- **Resources**: 100m CPU / 128Mi RAM (request)
- **Health Checks**: Liveness + Readiness on `/`

#### 3. **Catalogue Service** (`03-catalogue-deployment.yaml`)
- **Deployment**: 2 replicas
- **Image**: `livingdevopswithakhilesh/microservices:catalogue-*`
- **Port**: 5000
- **Environment**:
  - `DB_HOST`: RDS endpoint
  - `DB_USER`: root
  - `DB_PASSWORD`: From `catalogue-db-secrets` (Terraform)
  - `DB_NAME`: catalogue
- **Resources**: 100m CPU / 128Mi RAM (request)
- **Health Checks**: `/health` and `/ready`

#### 4. **Voting Service** (`04-voting-deployment.yaml`)
- **Deployment**: 2 replicas
- **Image**: `livingdevopswithakhilesh/microservices:voting-*`
- **Port**: 8080
- **Environment**:
  - `DB_HOST`: RDS endpoint
  - `DB_USER`: root
  - `DB_PASSWORD`: From `catalogue-db-secrets` (Terraform)
  - `DB_NAME`: voting
  - `SPRING_PROFILES_ACTIVE`: production
- **Resources**: 200m CPU / 256Mi RAM (request)
- **Health Checks**: `/actuator/health`

#### 5. **Recommendation Service** (`05-recommendation-deployment.yaml`)
- **Deployment**: 2 replicas
- **Image**: `livingdevopswithakhilesh/microservices:recommendation-*`
- **Port**: 8080
- **Environment**:
  - `PORT`: 8080
- **Resources**: 50m CPU / 64Mi RAM (request)
- **Health Checks**: `/` (changed from `/health` - not available)

#### 6. **HPA - Horizontal Pod Autoscaler** (`07-hpa.yaml`)
```yaml
- frontend-hpa: 2-5 replicas, 70% CPU target
- catalogue-hpa: 2-4 replicas, 70% CPU target
- voting-hpa: 2-4 replicas, 70% CPU target
- recco-hpa: 2-3 replicas, 70% CPU target
```

## How Everything Connects

### 🔄 Request Flow

1. **User Request** → `https://ms.akhileshmishra.tech`

2. **DNS Resolution** (Route53)
   - Route53 resolves `ms.akhileshmishra.tech` to ALB DNS

3. **ALB (Application Load Balancer)**
   - Terminates SSL/TLS using Let's Encrypt certificate
   - Routes based on hostname:
     - `ms.akhileshmishra.tech` → Frontend service
     - `catalogue.ms.akhileshmishra.tech` → Catalogue service
     - `voting.ms.akhileshmishra.tech` → Voting service
     - `recommendations.ms.akhileshmishra.tech` → Recco service

4. **Kubernetes Service** (ClusterIP)
   - Distributes traffic to healthy pods

5. **Pod** → Processes request
   - Frontend: Serves static content + calls other APIs
   - Catalogue/Voting: Query PostgreSQL database
   - Recco: Provides recommendations

### 🔐 Certificate Management Flow

1. **Terraform applies** → Creates cert-manager + ClusterIssuer + Certificate

2. **cert-manager watches** Certificate resource

3. **DNS-01 Challenge**:
   - cert-manager creates TXT record in Route53: `_acme-challenge.ms.akhileshmishra.tech`
   - Let's Encrypt validates domain ownership via DNS lookup
   - No temporary load balancers created! ✅

4. **Certificate issued**:
   - cert-manager stores certificate in `craftista-tls-secret`
   - Secret contains: `tls.crt`, `tls.key`

5. **Ingress uses certificate**:
   - ALB Controller reads `craftista-tls-secret`
   - Configures ALB with SSL certificate
   - Enables HTTPS on ALB

6. **Auto-renewal**:
   - cert-manager renews certificate 30 days before expiry
   - Process repeats automatically

## Deployment Steps

### Step 1: Apply Terraform Infrastructure
```bash
cd /Users/akhilesh/projects/may-bootcamp/class24-eks/infra
terraform init
terraform apply
```

**What gets created:**
- EKS cluster with worker nodes
- RDS PostgreSQL database
- Namespace `craftista`
- Secret `catalogue-db-secrets`
- cert-manager (Helm)
- ClusterIssuer `letsencrypt-prod`
- Certificate `craftista-tls-cert`
- Ingress `craftista-ingress` (creates ALB)
- Route53 DNS records (after ALB is ready)

**Wait time**: ~15-20 minutes

### Step 2: Verify Infrastructure
```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check ClusterIssuer
kubectl get clusterissuer

# Check Certificate status
kubectl get certificate -n craftista
kubectl describe certificate craftista-tls-cert -n craftista

# Check if TLS secret is created
kubectl get secret craftista-tls-secret -n craftista

# Check ingress
kubectl get ingress -n craftista
```

### Step 3: Deploy Application Manifests
```bash
cd /Users/akhilesh/projects/may-bootcamp/class24-eks/microservices-on-k8s/k8s-menifest-adv

# Apply deployments
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-frontend-deployment.yaml
kubectl apply -f 03-catalogue-deployment.yaml
kubectl apply -f 04-voting-deployment.yaml
kubectl apply -f 05-recommendation-deployment.yaml
kubectl apply -f 07-hpa.yaml
```

### Step 4: Monitor Deployment
```bash
# Watch pods
kubectl get pods -n craftista -w

# Check pod logs
kubectl logs -n craftista <pod-name>

# Check HPA status
kubectl get hpa -n craftista
```

### Step 5: Access Application
```bash
# Get ALB DNS
kubectl get ingress -n craftista craftista-ingress

# Test endpoints
curl https://ms.akhileshmishra.tech
curl https://catalogue.ms.akhileshmishra.tech/products
curl https://voting.ms.akhileshmishra.tech/api/origamis
curl https://recommendations.ms.akhileshmishra.tech/api/origami-of-the-day
```

## Troubleshooting

### Certificate Not Ready
```bash
# Check certificate status
kubectl describe certificate craftista-tls-cert -n craftista

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check if DNS challenge is working
kubectl get challenges -n craftista
```

### Pods CrashLooping
```bash
# Check logs
kubectl logs -n craftista <pod-name> --previous

# Common issues:
# 1. Database connection - Check RDS endpoint and secrets
# 2. Image pull errors - Check ECR/Docker Hub access
# 3. Health check failing - Check /health or / endpoints
```

### ALB Not Created
```bash
# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check ingress events
kubectl describe ingress -n craftista craftista-ingress
```

### Route53 Not Resolving
```bash
# Check DNS records
aws route53 list-resource-record-sets --hosted-zone-id <zone-id>

# Check ALB status
aws elbv2 describe-load-balancers --region ap-south-1

# Wait 5-10 minutes for DNS propagation
```

## Key Benefits of This Architecture

✅ **Single ALB** - Cost-effective (only 1 load balancer vs 5 with HTTP-01)
✅ **Free SSL** - Let's Encrypt certificates with auto-renewal
✅ **DNS-01 Validation** - No temporary load balancers created
✅ **Infrastructure as Code** - Everything reproducible via Terraform
✅ **Clean Separation** - Infrastructure (Terraform) + Apps (K8s manifests)
✅ **Auto-scaling** - HPA scales pods based on CPU/memory
✅ **Host-based Routing** - Clean subdomain URLs for each service
✅ **Automatic HTTPS** - All traffic redirected to HTTPS

## Resource Costs (Approximate)

- **EKS Cluster**: $0.10/hour (~$73/month)
- **Worker Nodes**: Varies by instance type
- **ALB**: $0.0225/hour (~$16/month) + data transfer
- **RDS**: Varies by instance type
- **Route53**: $0.50/month per hosted zone + queries
- **Let's Encrypt**: FREE
- **Data Transfer**: Varies

**Total estimated**: ~$100-200/month depending on usage

## Clean Up

```bash
# Delete Kubernetes resources
kubectl delete -f k8s-menifest-adv/

# Destroy Terraform infrastructure
cd infra/
terraform destroy
```

**Note**: Always destroy in reverse order (K8s → Terraform) to avoid orphaned resources.
