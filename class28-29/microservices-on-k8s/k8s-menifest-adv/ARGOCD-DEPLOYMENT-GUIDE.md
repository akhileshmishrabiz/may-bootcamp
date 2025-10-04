# ArgoCD Deployment Guide for Craftista Microservices

## 📋 Overview

This guide will help you deploy Craftista microservices using ArgoCD for GitOps-based continuous deployment.

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      GitOps Workflow                            │
└────────────────────────────────────────────────────────────────┘

GitHub Repository
    ↓ (Git Push)
┌───────────────────┐
│   ArgoCD Server   │ ← Monitors repository for changes
│  (in EKS cluster) │
└────────┬──────────┘
         ↓ (Sync)
┌────────────────────────────────────────────────────────────────┐
│               Kubernetes Cluster (EKS)                          │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Frontend    │  │  Catalogue   │  │    Voting    │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │    Recco     │  │   Ingress    │  │     HPA      │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└────────────────────────────────────────────────────────────────┘
```

## Prerequisites

✅ EKS cluster running
✅ kubectl configured
✅ Terraform infrastructure deployed
✅ Git repository accessible (GitHub)

## 🚀 Step-by-Step Deployment

### Step 1: Install ArgoCD

```bash
# Navigate to argocd-apps directory
cd /Users/akhilesh/projects/may-bootcamp/class24-eks/microservices-on-k8s/argocd-apps

# Create ArgoCD namespace
kubectl apply -f 01-argocd-namespace.yaml

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready (takes 2-3 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

**Verify Installation:**
```bash
kubectl get pods -n argocd

# You should see these pods running:
# - argocd-server
# - argocd-application-controller
# - argocd-repo-server
# - argocd-redis
# - argocd-dex-server
```

### Step 2: Access ArgoCD UI

**Option A: Port Forward (Quick Access)**
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
Access at: `https://localhost:8080`

**Option B: Create Ingress (Production)**
```bash
# Update 06-argocd-ingress.yaml with your domain
kubectl apply -f 06-argocd-ingress.yaml

# Get ALB DNS
kubectl get ingress argocd-server-ingress -n argocd
```

**Get Admin Password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Login Credentials:**
- Username: `admin`
- Password: (from command above)

### Step 3: Update Application Configuration

Before deploying, update the image references in `04-craftista-application.yaml`:

```bash
# Check current images
grep -A 5 "images:" 04-craftista-application.yaml
```

**Update if needed:**
```yaml
# Change from:
images:
  - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend:latest

# To:
images:
  - livingdevopswithakhilesh/microservices:frontend-644625f8de627843afd6fc916bc30459705c2726
  - livingdevopswithakhilesh/microservices:catalogue-644625f8de627843afd6fc916bc30459705c2726
  - livingdevopswithakhilesh/microservices:voting-644625f8de627843afd6fc916bc30459705c2726
  - livingdevopswithakhilesh/microservices:recommendation-644625f8de627843afd6fc916bc30459705c2726
```

### Step 4: Create ArgoCD Project

```bash
# Create Craftista project
kubectl apply -f 03-craftista-project.yaml

# Verify project creation
kubectl get appproject -n argocd
```

### Step 5: Deploy Application

**Option A: Single Application Deployment**
```bash
# Deploy the Craftista microservices application
kubectl apply -f 04-craftista-application.yaml

# Watch the sync status
kubectl get application -n argocd -w
```

**Option B: App of Apps Pattern (Recommended)**
```bash
# Deploy using app-of-apps pattern
kubectl apply -f 05-app-of-apps.yaml

# This will automatically deploy:
# - craftista-project
# - craftista-microservices
```

### Step 6: Monitor Deployment

**Via kubectl:**
```bash
# Check application status
kubectl get application craftista-microservices -n argocd

# Watch sync progress
kubectl get application -n argocd -w

# Check deployed resources
kubectl get pods -n craftista
```

**Via ArgoCD UI:**
1. Login to ArgoCD UI
2. Click on "craftista-microservices" application
3. View the application tree and sync status
4. Monitor health status of each resource

### Step 7: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n craftista

# Check services
kubectl get svc -n craftista

# Check ingress
kubectl get ingress -n craftista

# Test endpoints
kubectl get ingress -n craftista -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

## 🔄 How ArgoCD Works

### Sync Process

1. **Git as Source of Truth**
   - ArgoCD monitors: `https://github.com/akhileshmishrabiz/may-bootcamp.git`
   - Path: `class24-eks/microservices-on-k8s/k8s-menifest-adv`
   - Branch: `HEAD` (main/master)

2. **Automated Sync**
   - **Auto-Sync**: Enabled (deploys changes automatically)
   - **Self-Heal**: Enabled (fixes manual changes)
   - **Prune**: Enabled (removes deleted resources)

3. **Sync Waves**
   - Wave 1: Namespace, ConfigMaps, Secrets
   - Wave 2: Deployments
   - Wave 3: Ingress
   - Wave 4: HPA

### Making Changes

**Workflow:**
```bash
# 1. Make changes to manifests
cd /Users/akhilesh/projects/may-bootcamp/class24-eks/microservices-on-k8s/k8s-menifest-adv
vim 02-frontend-deployment.yaml  # Make your changes

# 2. Commit and push to Git
git add .
git commit -m "Update frontend replicas to 3"
git push origin main

# 3. ArgoCD auto-syncs (within 3 minutes)
# OR manually trigger sync
kubectl patch application craftista-microservices -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

**Via ArgoCD UI:**
1. Go to Application → craftista-microservices
2. Click "Sync" button
3. Review changes
4. Click "Synchronize"

## 🔐 RBAC Configuration

```bash
# Apply RBAC config (optional)
kubectl apply -f 07-rbac-config.yaml

# This creates roles:
# - Admin: Full access
# - DevOps: Infrastructure management
# - Developer: Application deployment
# - ReadOnly: View-only
```

## 📊 Operations

### Manual Sync
```bash
# Via kubectl
kubectl patch application craftista-microservices -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Via ArgoCD CLI (if installed)
argocd app sync craftista-microservices
```

### Refresh Application
```bash
# Force refresh from Git
kubectl patch application craftista-microservices -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"info":[{"name":"Reason","value":"Manual refresh"}]}}'
```

### View Application Details
```bash
# Get application status
kubectl get application craftista-microservices -n argocd -o yaml

# Get sync status
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.sync.status}'

# Get health status
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.health.status}'
```

### Rollback
```bash
# View history
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.history}'

# Rollback via UI:
# 1. Go to Application → craftista-microservices
# 2. Click "History and Rollback"
# 3. Select previous revision
# 4. Click "Rollback"
```

## 🐛 Troubleshooting

### Application Stuck in "Progressing"

```bash
# Check application events
kubectl describe application craftista-microservices -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=100

# Check if pods are starting
kubectl get pods -n craftista
kubectl describe pod <pod-name> -n craftista
```

### Sync Failed

```bash
# Check sync status
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.operationState}'

# Common issues:
# 1. Invalid YAML syntax
# 2. Resource conflicts
# 3. Insufficient permissions
# 4. Image pull errors

# Force sync
kubectl patch application craftista-microservices -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"syncStrategy":{"hook":{},"apply":{"force":true}}}}}'
```

### Repository Not Accessible

```bash
# Check repository connection
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.sourceType}'

# Verify repository URL
kubectl get application craftista-microservices -n argocd -o jsonpath='{.spec.source.repoURL}'

# For private repos, add credentials:
kubectl create secret generic github-credentials \
  -n argocd \
  --from-literal=username=your-username \
  --from-literal=password=your-token
```

### Out of Sync Status

```bash
# Check what's different
kubectl get application craftista-microservices -n argocd -o jsonpath='{.status.sync.comparedTo}'

# If manual changes were made in cluster:
# Option 1: Let ArgoCD self-heal (automatic if enabled)
# Option 2: Manually sync to revert changes
```

## 📈 Best Practices

### ✅ Do's

1. **Always commit to Git first**
   - Never make manual changes directly in cluster
   - Git is the source of truth

2. **Use sync waves**
   - Ensure proper resource ordering
   - Dependencies deploy first

3. **Enable self-heal**
   - Automatically fix drift
   - Maintain desired state

4. **Version your images**
   - Use specific tags, not `latest`
   - Makes rollbacks easier

5. **Monitor ArgoCD**
   - Set up alerts for sync failures
   - Monitor application health

### ❌ Don'ts

1. **Don't use `kubectl apply` for app resources**
   - Use Git commits instead
   - Let ArgoCD manage the sync

2. **Don't disable prune in production**
   - Orphaned resources waste money
   - Can cause conflicts

3. **Don't skip testing**
   - Test changes in staging first
   - Use different branches for environments

## 🎯 Current Configuration Summary

**Repository:** `https://github.com/akhileshmishrabiz/may-bootcamp.git`
**Path:** `class24-eks/microservices-on-k8s/k8s-menifest-adv`
**Branch:** `HEAD` (main/master)
**Namespace:** `craftista`

**Sync Policy:**
- ✅ Auto-Sync: Enabled
- ✅ Self-Heal: Enabled
- ✅ Prune: Enabled
- ✅ Retry: 5 attempts with backoff

**Applications Deployed:**
- frontend (2 replicas)
- catalogue (2 replicas)
- voting (2 replicas)
- recco (2 replicas)
- ingress (HTTP only, ALB)
- HPA for all services

## 🔄 Continuous Deployment Flow

```
Developer
   ↓ (1. Make code changes)
Git Repository
   ↓ (2. Push to main branch)
ArgoCD
   ↓ (3. Detects changes - within 3 min)
   ↓ (4. Syncs to cluster)
Kubernetes
   ↓ (5. Updates pods with new version)
Production 🚀
```

**Update Frequency:** ArgoCD checks Git every 3 minutes by default

## Next Steps

1. ✅ Push your current manifests to Git repository
2. ✅ Deploy ArgoCD (Steps 1-2)
3. ✅ Create Application (Steps 4-5)
4. ✅ Monitor deployment (Step 6)
5. ✅ Make a test change and watch auto-sync
6. 🔜 Set up notifications (Slack/Email)
7. 🔜 Configure multiple environments (dev/staging/prod)

---

**You now have GitOps-based continuous deployment! 🎉**

Any change you push to Git will automatically deploy to your cluster within 3 minutes!
