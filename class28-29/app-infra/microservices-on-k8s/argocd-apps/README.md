# ArgoCD GitOps Deployment for Craftista

This directory contains ArgoCD configurations for deploying Craftista microservices using GitOps principles.

## 📋 Files Overview

| File | Description |
|------|-------------|
| `01-argocd-namespace.yaml` | ArgoCD namespace |
| `02-argocd-install.yaml` | Installation instructions and service |
| `03-craftista-project.yaml` | ArgoCD project for Craftista |
| `04-craftista-application.yaml` | Main application manifest |
| `05-app-of-apps.yaml` | Meta-application for managing multiple apps |
| `06-argocd-ingress.yaml` | ArgoCD UI ingress with ALB |
| `07-rbac-config.yaml` | RBAC and permissions |

## 🚀 Quick Start

### Step 1: Install ArgoCD

```bash
# Create namespace
kubectl apply -f 01-argocd-namespace.yaml

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Configure ArgoCD

```bash
# Apply RBAC and configurations
kubectl apply -f 07-rbac-config.yaml
kubectl apply -f 06-argocd-ingress.yaml

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 3: Deploy Applications

**Option A: App of Apps Pattern (Recommended)**
```bash
# Deploy the meta-application
kubectl apply -f 05-app-of-apps.yaml
```

**Option B: Individual Applications**
```bash
# Deploy project and application
kubectl apply -f 03-craftista-project.yaml
kubectl apply -f 04-craftista-application.yaml
```

### Step 4: Access ArgoCD UI

```bash
# Get ALB DNS name
kubectl get ingress argocd-server-ingress -n argocd

# Or port-forward for local access
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: `https://argocd.ms.akhileshmishra.tech` (after DNS setup)

## 🏗️ Architecture

### GitOps Workflow
```
GitHub Repo → ArgoCD → Kubernetes Cluster
     ↓             ↓            ↓
  k8s-manifests  Sync Agent   Running Pods
```

### App of Apps Pattern
```
craftista-app-of-apps
├── craftista-project
└── craftista-microservices
    ├── frontend
    ├── catalogue  
    ├── voting
    ├── recommendations
    └── ingress + HPA
```

## ⚙️ Configuration

### Repository Structure
```
class24-eks/microservices-on-k8s/
├── k8s-menifest-adv/          # Application manifests
│   ├── kustomization.yaml     # Kustomize config
│   ├── 01-namespace.yaml
│   ├── 02-frontend-deployment.yaml
│   └── ...
└── argocd-apps/               # ArgoCD configurations
    ├── 04-craftista-application.yaml
    └── ...
```

### Sync Policies

**Automated Sync**:
- ✅ **Prune**: Remove resources not in Git
- ✅ **Self-Heal**: Automatically fix drift
- ✅ **Auto-Sync**: Deploy changes automatically

**Sync Waves**:
- Wave 1: Namespace, ConfigMaps, Secrets
- Wave 2: Deployments, Services  
- Wave 3: Ingress
- Wave 4: HPA

### Environment Management

Update `04-craftista-application.yaml` for different environments:

```yaml
# Production
source:
  path: class24-eks/microservices-on-k8s/k8s-menifest-adv
  kustomize:
    images:
      - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend:v1.0.0

# Staging  
source:
  path: class24-eks/microservices-on-k8s/k8s-menifest-staging
  kustomize:
    images:
      - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest
```

## 🔐 Security & RBAC

### Roles Defined:
- **Admin**: Full access to everything
- **DevOps**: Infrastructure management
- **Craftista-Developer**: Project-specific access
- **ReadOnly**: View-only access

### GitHub Integration:
1. Update `07-rbac-config.yaml` with your GitHub credentials
2. Create GitHub Personal Access Token
3. Update repository URL in applications

## 🔄 Operations

### Manual Sync
```bash
# Via CLI
argocd app sync craftista-microservices

# Via UI
ArgoCD Dashboard → Applications → craftista-microservices → Sync
```

### Refresh Repository
```bash
# Force refresh from Git
argocd app sync craftista-microservices --force
```

### Rollback
```bash
# Rollback to previous version
argocd app rollback craftista-microservices
```

### Health Checks
```bash
# Check application health
argocd app get craftista-microservices

# Check sync status
argocd app list
```

## 📊 Monitoring

### ArgoCD Metrics
- Application sync status
- Repository connection health
- Resource deployment status
- Sync performance

### Alerts Setup
Configure alerts for:
- Sync failures
- Application health degradation
- Repository connectivity issues
- Drift detection

## 🐛 Troubleshooting

### Sync Issues
```bash
# Check application status
kubectl get application craftista-microservices -n argocd -o yaml

# Check ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Check application controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### Repository Access Issues
```bash
# Test repository access
argocd repo list

# Update credentials
kubectl patch secret github-secret -n argocd -p '{"data":{"password":"<base64-encoded-token>"}}'
```

### SSL/TLS Issues
```bash
# Check certificate status
kubectl get certificate -n craftista
kubectl describe certificate argocd-tls-secret -n argocd

# Check ingress
kubectl describe ingress argocd-server-ingress -n argocd
```

### Common Issues:

1. **"Repository not accessible"**
   - Check GitHub token permissions
   - Verify repository URL
   - Update secret credentials

2. **"Application stuck in Progressing"**
   - Check sync waves and dependencies  
   - Verify resource quotas
   - Check image pull secrets

3. **"Ingress not working"**
   - Verify ALB controller is running
   - Check certificate ARN in ingress
   - Verify DNS records

## 🔧 Customization

### Adding New Applications
1. Create application manifest in `argocd-apps/`
2. Add to app-of-apps pattern or deploy individually
3. Configure RBAC permissions
4. Set up monitoring

### Multi-Environment Setup
1. Create environment-specific branches
2. Update `targetRevision` in applications
3. Configure different kustomization overlays
4. Set up promotion pipelines

## 📈 Best Practices

✅ **Use App of Apps pattern** for managing multiple applications
✅ **Enable automated sync with prune** for consistent state  
✅ **Use sync waves** for proper resource ordering
✅ **Set resource health checks** for all applications
✅ **Configure RBAC** for security
✅ **Monitor sync status** and set up alerts
✅ **Use Kustomize** for environment-specific configurations
✅ **Version your images** (avoid `latest` in production)

This setup provides a production-ready GitOps workflow with ArgoCD for managing Craftista microservices deployment!