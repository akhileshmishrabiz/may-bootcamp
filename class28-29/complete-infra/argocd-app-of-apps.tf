################################################################################
# ArgoCD App of Apps Pattern for Craftista Microservices
#
# This file implements the "App of Apps" pattern where a parent ArgoCD Application
# manages multiple child Applications (one per microservice).
#
# Benefits:
# - Independent deployment per microservice
# - Team ownership and RBAC per service
# - Different sync policies per service
# - Granular rollback capability
# - Better monitoring and observability
#
# To use this instead of the single app:
# 1. Comment out kubectl_manifest.craftista_application in argocd.tf
# 2. Uncomment this entire file
# 3. Ensure your Git repo has the correct structure (see below)
################################################################################

# ============================================================================
# Required Git Repository Structure
# ============================================================================
#
# class28-29/microservices-on-k8s/
# ├── apps/                              # App of Apps definitions
# │   ├── frontend.yaml
# │   ├── catalogue.yaml
# │   ├── voting.yaml
# │   └── recommendations.yaml
# └── k8s-menifest-adv/                  # Kubernetes manifests
#     ├── 02-frontend-deployment.yaml
#     ├── 03-catalogue-deployment.yaml
#     ├── 04-voting-deployment.yaml
#     └── 05-recommendation-deployment.yaml
#
# ============================================================================

# # Parent Application - Manages all child applications
# # This is the only app you need to sync manually (if automated sync is disabled)
# resource "kubectl_manifest" "craftista_app_of_apps" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-app-of-apps
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: craftista
#         app.kubernetes.io/component: root
#     spec:
#       project: craftista

#       # Source - Points to directory containing child Application definitions
#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/apps
#         targetRevision: HEAD
#         directory:
#           recurse: true  # Include all YAML files in subdirectories

#       # Destination
#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${kubernetes_namespace.argocd.metadata[0].name}

#       # Sync Policy - Parent app auto-syncs child app definitions
#       syncPolicy:
#         automated:
#           prune: true
#           selfHeal: true
#         syncOptions:
#           - CreateNamespace=true

#       # Keep last 5 revisions
#       revisionHistoryLimit: 5
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# ============================================================================
# Alternative: Define Child Applications Directly in Terraform
# Use this if you prefer Terraform to manage everything
# ============================================================================

# # Frontend Application
# resource "kubectl_manifest" "craftista_frontend" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-frontend
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: frontend
#         app.kubernetes.io/component: microservice
#         app.kubernetes.io/part-of: craftista
#     spec:
#       project: craftista

#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/k8s-menifest-adv
#         targetRevision: HEAD

#         # Directory plugin to filter only frontend resources
#         directory:
#           include: '02-frontend-*.yaml'

#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${var.namespace}

#       syncPolicy:
#         automated:
#           prune: true
#           selfHeal: true
#         syncOptions:
#           - CreateNamespace=true
#         retry:
#           limit: 3
#           backoff:
#             duration: 5s
#             factor: 2
#             maxDuration: 1m

#       revisionHistoryLimit: 10
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# # Catalogue Application
# resource "kubectl_manifest" "craftista_catalogue" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-catalogue
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: catalogue
#         app.kubernetes.io/component: microservice
#         app.kubernetes.io/part-of: craftista
#     spec:
#       project: craftista

#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/k8s-menifest-adv
#         targetRevision: HEAD

#         directory:
#           include: '03-catalogue-*.yaml'

#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${var.namespace}

#       syncPolicy:
#         automated:
#           prune: true
#           selfHeal: true
#         syncOptions:
#           - CreateNamespace=true
#         retry:
#           limit: 3
#           backoff:
#             duration: 5s
#             factor: 2
#             maxDuration: 1m

#       revisionHistoryLimit: 10
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# # Voting Application
# resource "kubectl_manifest" "craftista_voting" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-voting
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: voting
#         app.kubernetes.io/component: microservice
#         app.kubernetes.io/part-of: craftista
#     spec:
#       project: craftista

#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/k8s-menifest-adv
#         targetRevision: HEAD

#         directory:
#           include: '04-voting-*.yaml'

#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${var.namespace}

#       syncPolicy:
#         automated:
#           prune: true
#           selfHeal: true
#         syncOptions:
#           - CreateNamespace=true
#         retry:
#           limit: 3
#           backoff:
#             duration: 5s
#             factor: 2
#             maxDuration: 1m

#       revisionHistoryLimit: 10
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# # Recommendations Application
# resource "kubectl_manifest" "craftista_recommendations" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-recommendations
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: recommendations
#         app.kubernetes.io/component: microservice
#         app.kubernetes.io/part-of: craftista
#     spec:
#       project: craftista

#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/k8s-menifest-adv
#         targetRevision: HEAD

#         directory:
#           include: '05-recommendation-*.yaml'

#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${var.namespace}

#       syncPolicy:
#         automated:
#           prune: true
#           selfHeal: true
#         syncOptions:
#           - CreateNamespace=true
#         retry:
#           limit: 3
#           backoff:
#             duration: 5s
#             factor: 2
#             maxDuration: 1m

#       revisionHistoryLimit: 10
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# ============================================================================
# Outputs for App of Apps
# ============================================================================

# output "argocd_applications" {
#   description = "List of ArgoCD applications"
#   value = {
#     # root = "craftista-app-of-apps"
#     frontend        = "craftista-frontend"
#     catalogue       = "craftista-catalogue"
#     voting          = "craftista-voting"
#     recommendations = "craftista-recommendations"
#   }
# }
