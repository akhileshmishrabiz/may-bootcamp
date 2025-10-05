# ArgoCD App of Apps Deployment Guide

Complete guide for deploying Craftista microservices using ArgoCD's App of Apps pattern.

## Prerequisites

✅ EKS cluster running
✅ kubectl configured
✅ ArgoCD installed (if not, see installation below)
✅ Git repository accessible

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  craftista-app-of-apps (Parent Application)     │
│  Manages all child applications                 │
└───────────────────┬─────────────────────────────┘
                    │
        ┌───────────┴───────────┐
        │                       │
        ▼                       ▼
┌───────────────────┐   ┌──────────────────────┐
│ craftista-project │   │ craftista-           │
│ (ArgoCD Project)  │   │ microservices        │
└───────────────────┘   │ (Main Application)   │
                        └──────────┬───────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
              ┌─────────┐    ┌──────────┐   ┌────────┐
              │Frontend │    │Catalogue │   │Voting  │
              └─────────┘    └──────────┘   └────────┘
```

## Step 1: Install ArgoCD (If Not Installed)

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Install ArgoCD CLI (optional but recommended)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

## Step 2: Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward to access UI locally
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI
argocd login localhost:8080 --username admin --password <password-from-above>

# Change default password (recommended)
argocd account update-password
```

Access UI at: https://localhost:8080

## Step 3: Deploy App of Apps

```bash
# Navigate to the argocd-apps directory
cd class28-29/microservices-on-k8s/argocd-apps

# Deploy the parent application
kubectl apply -f app-of-apps.yaml

# Verify deployment
kubectl get applications -n argocd
```

Expected output:
```
NAME                        SYNC STATUS   HEALTH STATUS
craftista-app-of-apps       Synced        Healthy
craftista-microservices     Synced        Healthy
```

## Step 4: Verify Microservices Deployment

```bash
# Check all resources in craftista namespace
kubectl get all -n craftista

# Expected resources:
# - 4 Deployments (frontend, catalogue, voting, recco)
# - 4 Services
# - 4 HPAs
# - Multiple Pods

# Check specific deployments
kubectl get deployments -n craftista
kubectl get svc -n craftista
kubectl get ingress -n craftista

# Check pod status
kubectl get pods -n craftista -w
```

## Step 5: Test the Application

```bash
# Get ingress URL
kubectl get ingress craftista-ingress -n craftista

# Test endpoints
curl -I https://ms1.akhileshmishra.tech
curl -I https://catalogue.ms1.akhileshmishra.tech
curl -I https://voting.ms1.akhileshmishra.tech
curl -I https://recommendations.ms1.akhileshmishra.tech
```

## GitOps Workflow

### How It Works

1. **Developer updates code** and pushes to Git
   ```bash
   git add apps/craftista-microservices.yaml
   git commit -m "Update frontend to v2.0.0"
   git push origin main
   ```

2. **ArgoCD detects changes** (polls every 3 minutes)
   - Compares Git state vs Cluster state
   - Shows "OutOfSync" in UI

3. **ArgoCD auto-syncs** (if automated sync enabled)
   - Applies changes to cluster
   - Updates resources
   - Marks as "Synced"

4. **Verification**
   ```bash
   argocd app get craftista-microservices
   kubectl get pods -n craftista
   ```

### Update Application Image

```bash
# Edit the application manifest
vim apps/craftista-microservices.yaml

# Update image version:
kustomize:
  images:
    - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend:v2.0.0  # Changed from :latest

# Commit and push
git add apps/craftista-microservices.yaml
git commit -m "Update frontend to v2.0.0"
git push origin main

# ArgoCD will auto-sync within 3 minutes
# Or manually sync:
argocd app sync craftista-microservices
```

## Advanced Operations

### Manual Sync

```bash
# Sync parent app (syncs all children)
argocd app sync craftista-app-of-apps

# Sync specific child app
argocd app sync craftista-microservices

# Force sync (bypass health checks)
argocd app sync craftista-microservices --force

# Prune resources
argocd app sync craftista-microservices --prune
```

### Rollback

**Option 1: Git Revert (Recommended)**
```bash
# View git history
git log --oneline

# Revert to previous commit
git revert HEAD
git push origin main

# ArgoCD auto-syncs to previous state
```

**Option 2: ArgoCD History**
```bash
# View deployment history
argocd app history craftista-microservices

# Rollback to specific revision
argocd app rollback craftista-microservices <revision-number>
```

### Pause Auto-Sync

```bash
# Disable auto-sync temporarily
argocd app set craftista-microservices --sync-policy none

# Re-enable auto-sync
argocd app set craftista-microservices --sync-policy automated
```

### View Sync Status

```bash
# Get application details
argocd app get craftista-microservices

# List all applications
argocd app list

# View sync diff
argocd app diff craftista-microservices

# Watch sync progress
argocd app wait craftista-microservices --sync
```

## Monitoring & Observability

### Check Application Health

```bash
# Via ArgoCD CLI
argocd app get craftista-microservices

# Via kubectl
kubectl describe application craftista-microservices -n argocd

# Check events
kubectl get events -n craftista --sort-by='.lastTimestamp'
```

### View Logs

```bash
# ArgoCD application controller logs
kubectl logs -n argocd deployment/argocd-application-controller --tail=100 -f

# ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server --tail=100 -f

# Application pod logs
kubectl logs -n craftista deployment/frontend --tail=100 -f
```

### Metrics (if Prometheus installed)

```bash
# ArgoCD metrics endpoint
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082

# Access metrics at: http://localhost:8082/metrics
```

## Troubleshooting

### Issue: Application Stuck in "Progressing"

```bash
# Check sync status
kubectl describe application craftista-microservices -n argocd

# Check pod status
kubectl get pods -n craftista

# Force sync
argocd app sync craftista-microservices --force --prune

# Delete and recreate
kubectl delete application craftista-microservices -n argocd
kubectl apply -f apps/craftista-microservices.yaml
```

### Issue: "Repository not accessible"

```bash
# Check repository connection
argocd repo list

# Add repository with credentials
argocd repo add https://github.com/akhileshmishrabiz/may-bootcamp.git \
  --username <username> \
  --password <github-token>

# Or via UI: Settings → Repositories → Connect Repo
```

### Issue: Sync Fails with Permission Error

```bash
# Check ArgoCD project permissions
kubectl get appproject craftista -n argocd -o yaml

# Ensure project allows the namespace
spec:
  destinations:
    - namespace: craftista
      server: https://kubernetes.default.svc

# Update project if needed
kubectl apply -f apps/craftista-project.yaml
```

### Issue: Images Not Updating

```bash
# Force image pull policy
kubectl set image deployment/frontend frontend=...image...:v2.0.0 -n craftista

# Or edit deployment
kubectl edit deployment frontend -n craftista

# Change imagePullPolicy to Always:
spec:
  template:
    spec:
      containers:
      - imagePullPolicy: Always
```

### Issue: Ingress Not Working

```bash
# Check ingress status
kubectl describe ingress craftista-ingress -n craftista

# Check NLB/ALB creation
kubectl get svc -n ingress-nginx

# Check certificate
kubectl get certificate -n craftista
kubectl describe certificate craftista-tls-cert -n craftista

# Check DNS
dig ms1.akhileshmishra.tech
```

## Clean Up

### Delete Application

```bash
# Delete via ArgoCD (keeps resources)
argocd app delete craftista-microservices --cascade=false

# Delete via ArgoCD (deletes resources)
argocd app delete craftista-microservices

# Delete via kubectl
kubectl delete application craftista-microservices -n argocd
```

### Delete App of Apps

```bash
# This will delete all child applications
argocd app delete craftista-app-of-apps

# Or via kubectl
kubectl delete application craftista-app-of-apps -n argocd
```

### Uninstall ArgoCD

```bash
# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete namespace
kubectl delete namespace argocd
```

## Best Practices

1. ✅ **Use Git branches for environments**
   - main → production
   - staging → staging environment
   - dev → development environment

2. ✅ **Version your images**
   - Avoid `:latest` in production
   - Use semantic versioning: `v1.0.0`

3. ✅ **Enable auto-sync with self-heal**
   - Prevents manual changes
   - Maintains Git as source of truth

4. ✅ **Use sync waves for dependencies**
   - Ensure proper resource ordering
   - Prevent race conditions

5. ✅ **Monitor sync status**
   - Set up alerts for sync failures
   - Regular health checks

6. ✅ **Test in staging first**
   - Never deploy directly to production
   - Use PR-based workflows

## Quick Reference

```bash
# Deploy everything
kubectl apply -f app-of-apps.yaml

# Check status
kubectl get applications -n argocd
argocd app list

# Sync manually
argocd app sync craftista-app-of-apps

# View details
argocd app get craftista-microservices

# Rollback
git revert HEAD && git push

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Next Steps

- [ ] Set up CI/CD pipeline to update image tags
- [ ] Configure RBAC for team access
- [ ] Set up monitoring and alerts
- [ ] Implement multi-environment deployment
- [ ] Configure webhooks for instant sync
- [ ] Set up image scanning and security policies

---

**Your Craftista microservices are now managed with GitOps! 🚀**

For more information, see:
- [APP-OF-APPS-README.md](APP-OF-APPS-README.md)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
