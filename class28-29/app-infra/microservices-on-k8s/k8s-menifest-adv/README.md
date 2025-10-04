# Production Kubernetes Manifests

## Quick Deployment Guide

### 1. Prerequisites
- EKS cluster with AWS Load Balancer Controller installed
- ACM certificate for `*.ms.akhileshmishra.tech` and `ms.akhileshmishra.tech`
- Database secrets created via Terraform

### 2. Create ACM Certificate
```bash
# In AWS Console → Certificate Manager
# Request certificate for:
# - ms.akhileshmishra.tech
# - *.ms.akhileshmishra.tech
# Choose DNS validation
# Copy the certificate ARN after validation
```

### 3. Update Ingress with Certificate ARN
Edit `06-ingress.yaml` and uncomment the certificate line:
```yaml
alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:ap-south-1:339713040609:certificate/YOUR-CERT-ID"
```

### 4. Deploy All Manifests

**Option A: Using Kustomize (Recommended)**
```bash
# Deploy using kustomization.yaml
kubectl apply -k k8s-menifest-adv/

# Or build and preview first
kubectl kustomize k8s-menifest-adv/ | kubectl apply -f -
```

**Option B: Direct Application**
```bash
kubectl apply -f k8s-menifest-adv/
```

### 5. Get ALB DNS
```bash
kubectl get ingress -n craftista craftista-ingress
```

### 6. Configure Route 53
Add these A records (Alias) pointing to your ALB:
- `ms.akhileshmishra.tech`
- `catalogue.ms.akhileshmishra.tech`
- `voting.ms.akhileshmishra.tech`
- `recommendations.ms.akhileshmishra.tech`

### 7. Test Services
```bash
# Frontend
curl https://ms.akhileshmishra.tech

# APIs
curl https://catalogue.ms.akhileshmishra.tech/products
curl https://voting.ms.akhileshmishra.tech/api/origamis
curl https://recommendations.ms.akhileshmishra.tech/api/origami-of-the-day
```

## Manifest Files

| File | Description |
|------|-------------|
| `01-namespace.yaml` | Creates craftista namespace |
| `02-frontend-deployment.yaml` | Frontend service (Node.js) |
| `03-catalogue-deployment.yaml` | Catalogue API (Python) |
| `04-voting-deployment.yaml` | Voting API (Java Spring) |
| `05-recommendation-deployment.yaml` | Recommendation API (Go) |
| `06-ingress.yaml` | ALB ingress with subdomain routing |
| `07-hpa.yaml` | Autoscaling configuration |

## Production Features

✅ **TLS/HTTPS** - ACM certificate for secure connections
✅ **Subdomain Routing** - Clean URLs for each service
✅ **Health Checks** - Liveness and readiness probes
✅ **Resource Limits** - CPU and memory constraints
✅ **Autoscaling** - HPA based on CPU/memory usage
✅ **Single ALB** - Cost-effective load balancing

## Kustomization Features

The `kustomization.yaml` provides advanced deployment features:

### 📋 **Resource Management**
- **Ordered Deployment**: Resources deploy in correct dependency order
- **Common Labels**: All resources get consistent labeling
- **Namespace Management**: All resources deployed to `craftista` namespace

### 🏷️ **Image Management**
```bash
# Update image versions easily
images:
  - name: 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend
    newTag: v2.0.0  # Change version here
```

### ⚙️ **Configuration Management**
- **ConfigMaps**: Environment-specific configurations
- **Secrets**: Placeholder for Terraform-managed secrets
- **Resource Patches**: Production-specific resource limits

### 🎯 **Advanced Features**
```bash
# Preview changes before applying
kubectl kustomize k8s-menifest-adv/

# Deploy with custom image tags
kubectl kustomize k8s-menifest-adv/ | sed 's/latest/v1.2.3/g' | kubectl apply -f -

# Deploy to different namespace
kubectl kustomize k8s-menifest-adv/ | kubectl apply -n staging -f -
```

### 📊 **Production Patches**
The kustomization automatically applies production-specific patches:
- **Frontend**: 1000m CPU, 1Gi memory
- **Catalogue**: 800m CPU, 1Gi memory  
- **Voting**: 1200m CPU, 2Gi memory
- **Recommendations**: 400m CPU, 512Mi memory

## Troubleshooting

### ALB Not Created
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
kubectl describe ingress -n craftista craftista-ingress
```

### DNS Not Resolving
- Wait 5-10 minutes for DNS propagation
- Check Route 53 records point to correct ALB

### Pods Not Ready
```bash
kubectl get pods -n craftista
kubectl describe pod <pod-name> -n craftista
kubectl logs <pod-name> -n craftista
```

### Kustomize Issues
```bash
# Validate kustomization.yaml
kubectl kustomize k8s-menifest-adv/ --dry-run=client

# Check resource generation
kubectl kustomize k8s-menifest-adv/ | grep -A5 -B5 "kind: Deployment"
```