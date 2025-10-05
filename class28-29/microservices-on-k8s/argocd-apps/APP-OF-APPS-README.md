# App of Apps Pattern Deployment

This directory contains ArgoCD configurations using the **App of Apps** pattern for deploying Craftista microservices.

## What is App of Apps Pattern?

The App of Apps pattern is a GitOps approach where you have a parent ArgoCD Application that manages child Application manifests. This provides:

- **Single source of truth**: One parent app manages all child apps
- **Declarative deployment**: All applications defined in Git
- **Automated management**: Parent app auto-syncs child apps
- **Dependency management**: Control deployment order with sync waves
- **Easy rollback**: Revert Git commits to rollback entire stack

## Architecture

```
craftista-app-of-apps (Parent Application)
    │
    ├── craftista-project.yaml (ArgoCD Project)
    │
    └── craftista-microservices.yaml (Child Application)
        ├── Frontend
        ├── Catalogue
        ├── Voting
        └── Recommendations
```

## Directory Structure

```
argocd-apps/
├── app-of-apps.yaml                    # Parent Application (deploy this)
├── apps/                                # Child Application manifests
│   ├── craftista-project.yaml          # ArgoCD Project definition
│   └── craftista-microservices.yaml    # Main microservices app
└── APP-OF-APPS-README.md               # This file
```

## Prerequisites

1. **EKS cluster** running with kubectl access
2. **ArgoCD installed** in the cluster
3. **GitHub repository** accessible from cluster
4. **Route53 domain** configured (optional for ingress)

## Deployment Steps

### Option 1: Quick Deploy (Recommended)

```bash
# 1. Ensure ArgoCD is installed
kubectl get pods -n argocd

# 2. Deploy the App of Apps
kubectl apply -f app-of-apps.yaml

# 3. Watch the deployment
kubectl get applications -n argocd -w
```

That's it! The parent app will automatically create and manage all child applications.

### Option 2: Manual Deploy (Individual Apps)

```bash
# 1. Deploy project
kubectl apply -f apps/craftista-project.yaml

# 2. Deploy microservices
kubectl apply -f apps/craftista-microservices.yaml

# 3. Verify
kubectl get applications -n argocd
```

## Verification

```bash
# Check all applications
kubectl get applications -n argocd

# Expected output:
# NAME                        SYNC STATUS   HEALTH STATUS
# craftista-app-of-apps       Synced        Healthy
# craftista-microservices     Synced        Healthy

# Check deployed resources
kubectl get all -n craftista

# Check sync status
argocd app list
argocd app get craftista-microservices
```

## Access ArgoCD UI

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Port forward (if no ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Or access via ingress
# https://argocd.ms1.akhileshmishra.tech
```

## Customization

### Adding New Applications

1. Create a new application manifest in `apps/` directory:

```yaml
# apps/new-service.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: new-service
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: craftista
  source:
    repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
    path: path/to/manifests
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: craftista
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

2. Commit and push to Git - ArgoCD will automatically pick it up!

### Changing Image Versions

Edit `apps/craftista-microservices.yaml`:

```yaml
kustomize:
  images:
    - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/frontend:v2.0.0  # Change version
    - 339713040609.dkr.ecr.ap-south-1.amazonaws.com/catalogue:v1.5.0
```

Commit and push - ArgoCD syncs automatically.

### Environment-Specific Deployments

Create separate branches or directories:

```
apps/
├── dev/
│   └── craftista-microservices.yaml  # Uses :latest tags
├── staging/
│   └── craftista-microservices.yaml  # Uses :stable tags
└── prod/
    └── craftista-microservices.yaml  # Uses :v1.0.0 tags
```

Then deploy different app-of-apps for each environment.

## Sync Waves

Sync waves control deployment order (lower numbers deploy first):

- **Wave -2**: Projects
- **Wave -1**: Namespaces
- **Wave 0**: Default (ConfigMaps, Secrets)
- **Wave 1**: Applications (Deployments, Services)
- **Wave 2**: Ingress
- **Wave 3**: HPA

Defined in `metadata.annotations`:
```yaml
annotations:
  argocd.argoproj.io/sync-wave: "1"
```

## Operations

### Manual Sync

```bash
# Sync parent app (syncs all children)
argocd app sync craftista-app-of-apps

# Sync specific child app
argocd app sync craftista-microservices

# Force sync (ignore diff)
argocd app sync craftista-microservices --force
```

### Rollback

```bash
# Option 1: Git revert (recommended)
git revert <commit-hash>
git push origin main

# Option 2: ArgoCD history
argocd app rollback craftista-microservices
argocd app history craftista-microservices
```

### Refresh Apps

```bash
# Refresh from Git
argocd app get craftista-app-of-apps --refresh

# Hard refresh (clear cache)
argocd app get craftista-app-of-apps --hard-refresh
```

## Troubleshooting

### App Stuck in Progressing

```bash
# Check sync status
kubectl describe application craftista-microservices -n argocd

# Check logs
kubectl logs -n argocd deployment/argocd-application-controller

# Force sync
argocd app sync craftista-microservices --force --prune
```

### Repository Not Accessible

```bash
# Check repo connectivity
argocd repo list

# Add repository (if needed)
argocd repo add https://github.com/akhileshmishrabiz/may-bootcamp.git \
  --username <username> \
  --password <token>
```

### Sync Failures

```bash
# Get detailed error
argocd app get craftista-microservices

# Check events
kubectl get events -n craftista --sort-by='.lastTimestamp'

# Delete and re-sync
kubectl delete application craftista-microservices -n argocd
kubectl apply -f apps/craftista-microservices.yaml
```

## Best Practices

✅ **Use sync waves** for proper resource ordering
✅ **Enable automated sync with prune** for consistency
✅ **Use self-heal** to prevent manual changes
✅ **Version your images** (avoid `:latest` in production)
✅ **Keep app manifests in Git** (single source of truth)
✅ **Use ArgoCD Projects** for multi-tenancy and RBAC
✅ **Monitor sync status** and set up alerts
✅ **Test in staging** before promoting to production

## References

- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [ArgoCD Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)

---

**Quick Commands Reference:**

```bash
# Deploy everything
kubectl apply -f app-of-apps.yaml

# Check status
kubectl get applications -n argocd

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Sync manually
argocd app sync craftista-app-of-apps

# Rollback
git revert HEAD && git push
```

Now your Craftista microservices are managed using GitOps! 🚀
