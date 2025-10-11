# ################################################################################
# # ArgoCD Installation and Configuration
# #
# # This file deploys ArgoCD for GitOps-based continuous deployment of the
# # Craftista microservices application. ArgoCD monitors the Git repository and
# # automatically syncs changes to the Kubernetes cluster.
# #
# # Components:
# # - ArgoCD Server (Web UI and API)
# # - ArgoCD Application Controller (manages apps)
# # - ArgoCD Repo Server (Git repository interaction)
# # - Redis (caching)
# # - ArgoCD Project (for Craftista)
# # - ArgoCD Application (auto-sync from Git)
# ################################################################################

# # Create dedicated namespace for ArgoCD
# resource "kubernetes_namespace" "argocd" {
#   metadata {
#     name = "argocd"

#     labels = {
#       name        = "argocd"
#       managed-by  = "terraform"
#       environment = var.environment
#     }
#   }
# }

# # Install ArgoCD using the official Helm chart
# # Chart documentation: https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd
# resource "helm_release" "argocd" {
#   name       = "argocd"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   namespace  = kubernetes_namespace.argocd.metadata[0].name
#   version    = "7.7.12" # Latest stable version as of Oct 2024 (ArgoCD v2.12.x)

#   # Helm values configuration
#   values = [
#     yamlencode({
#       # ========================================================================
#       # Global Configuration
#       # ========================================================================
#       global = {
#         # Domain for ArgoCD server (used in UI redirects and OIDC)
#         domain = "argocd.${var.subdomain}.${var.domain_name}"
#       }

#       # ========================================================================
#       # ArgoCD Server Configuration (Web UI + API)
#       # ========================================================================
#       server = {
#         # Run 2 replicas for high availability
#         replicas = 2

#         # Service configuration
#         service = {
#           type = "ClusterIP" # Using ClusterIP - exposed via Ingress
#         }

#         # Disable built-in ingress (we create our own with cert-manager)
#         ingress = {
#           enabled = false
#         }

#         # Resource limits for server pods
#         resources = {
#           requests = {
#             cpu    = "100m"
#             memory = "128Mi"
#           }
#           limits = {
#             cpu    = "500m"
#             memory = "512Mi"
#           }
#         }

#         # Enable Prometheus metrics (optional - requires Prometheus operator)
#         metrics = {
#           enabled = true
#           serviceMonitor = {
#             enabled = false # Set to true if you have Prometheus operator
#           }
#         }

#         # Custom resource health checks
#         # Teaches ArgoCD how to determine if cert-manager Certificates are healthy
#         config = {
#           "resource.customizations" = <<-EOT
#             cert-manager.io/Certificate:
#               health.lua: |
#                 hs = {}
#                 if obj.status ~= nil then
#                   if obj.status.conditions ~= nil then
#                     for i, condition in ipairs(obj.status.conditions) do
#                       if condition.type == "Ready" and condition.status == "False" then
#                         hs.status = "Degraded"
#                         hs.message = condition.message
#                         return hs
#                       end
#                       if condition.type == "Ready" and condition.status == "True" then
#                         hs.status = "Healthy"
#                         hs.message = condition.message
#                         return hs
#                       end
#                     end
#                   end
#                 end
#                 hs.status = "Progressing"
#                 hs.message = "Waiting for certificate"
#                 return hs
#           EOT
#         }

#         # ======================================================================
#         # RBAC Configuration
#         # Defines roles and permissions for different user types
#         # ======================================================================
#         # rbacConfig = {
#         #   # Default policy for all users (readonly access)
#         #   "policy.default" = "role:readonly"

#         #   # Policy rules in CSV format
#         #   "policy.csv" = <<-EOT
#         #     # Admin role - full access to everything
#         #     p, role:admin, applications, *, */*, allow
#         #     p, role:admin, clusters, *, *, allow
#         #     p, role:admin, repositories, *, *, allow
#         #     p, role:admin, projects, *, *, allow
#         #     p, role:admin, accounts, *, *, allow
#         #     p, role:admin, certificates, *, *, allow

#         #     # DevOps role - manage applications and view infrastructure
#         #     p, role:devops, applications, *, */*, allow
#         #     p, role:devops, clusters, get, *, allow
#         #     p, role:devops, repositories, get, *, allow
#         #     p, role:devops, projects, get, *, allow

#         #     # Developer role - manage only Craftista apps
#         #     p, role:developer, applications, *, craftista/*, allow
#         #     p, role:developer, applications, get, */*, allow

#         #     # ReadOnly role - view-only access (default)
#         #     p, role:readonly, applications, get, */*, allow
#         #     p, role:readonly, clusters, get, *, allow
#         #     p, role:readonly, repositories, get, *, allow
#         #     p, role:readonly, projects, get, *, allow

#         #     # Bind the default admin user to admin role
#         #     g, admin, role:admin
#         #   EOT
#         # }
#       }

#       # ========================================================================
#       # Application Controller Configuration
#       # Manages the application state and sync operations
#       # ========================================================================
#       controller = {
#         replicas = 1 # Single replica is sufficient for small deployments

#         resources = {
#           requests = {
#             cpu    = "250m"
#             memory = "512Mi"
#           }
#           limits = {
#             cpu    = "1000m"
#             memory = "1Gi"
#           }
#         }

#         metrics = {
#           enabled = true
#           serviceMonitor = {
#             enabled = false
#           }
#         }
#       }

#       # ========================================================================
#       # Repo Server Configuration
#       # Handles Git repository cloning and manifest generation
#       # ========================================================================
#       repoServer = {
#         replicas = 2 # Multiple replicas for faster sync operations

#         resources = {
#           requests = {
#             cpu    = "100m"
#             memory = "256Mi"
#           }
#           limits = {
#             cpu    = "500m"
#             memory = "512Mi"
#           }
#         }

#         metrics = {
#           enabled = true
#           serviceMonitor = {
#             enabled = false
#           }
#         }
#       }

#       # ========================================================================
#       # Dex Configuration (SSO/OAuth)
#       # Disabled for now - using local admin account
#       # ========================================================================
#       dex = {
#         enabled = false
#       }

#       # ========================================================================
#       # Redis Configuration
#       # Used for caching and session management
#       # ========================================================================
#       redis = {
#         enabled = true

#         resources = {
#           requests = {
#             cpu    = "100m"
#             memory = "128Mi"
#           }
#           limits = {
#             cpu    = "200m"
#             memory = "256Mi"
#           }
#         }
#       }

#       # ========================================================================
#       # Additional Configuration Parameters
#       # ========================================================================
#       configs = {
#         params = {
#           # Run server in insecure mode (TLS is handled by NGINX Ingress)
#           "server.insecure" = "true"

#           # Label to use for tracking application instances
#           "application.instanceLabelKey" = "argocd.argoproj.io/instance"
#         }
#       }
#     })
#   ]

#   depends_on = [
#     kubernetes_namespace.argocd,
#     helm_release.nginx_ingress # Ensure ingress controller is ready
#   ]
# }

# # ============================================================================
# # ArgoCD Ingress Configuration
# # Exposes ArgoCD UI at https://argocd.ms1.akhileshmishra.tech
# # Uses the same NGINX Ingress Controller and NLB as the application
# # ============================================================================
# resource "kubernetes_ingress_v1" "argocd" {
#   metadata {
#     name      = "argocd-server-ingress"
#     namespace = kubernetes_namespace.argocd.metadata[0].name

#     annotations = {
#       # cert-manager will automatically create a certificate for this ingress
#       # The certificate will be stored in argocd-tls-secret in the argocd namespace
#       "cert-manager.io/cluster-issuer" = "letsencrypt-prod"

#       # Force SSL redirect (HTTP -> HTTPS)
#       "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
#       "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"

#       # ArgoCD server runs HTTP, NGINX handles HTTPS
#       "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"

#       # Additional NGINX settings for ArgoCD compatibility
#       "nginx.ingress.kubernetes.io/proxy-body-size" = "100m"
#     }
#   }

#   spec {
#     # Use the same NGINX ingress controller (shares NLB with application)
#     ingress_class_name = "nginx"

#     # TLS configuration
#     tls {
#       hosts = [
#         "argocd.${var.subdomain}.${var.domain_name}"
#       ]
#       # cert-manager will automatically create this secret
#       secret_name = "argocd-tls-secret"
#     }

#     # Routing rule for ArgoCD UI
#     rule {
#       host = "argocd.${var.subdomain}.${var.domain_name}"

#       http {
#         path {
#           path      = "/"
#           path_type = "Prefix"

#           backend {
#             service {
#               # ArgoCD server service name (created by Helm chart)
#               name = "argocd-server"
#               port {
#                 number = 80
#               }
#             }
#           }
#         }
#       }
#     }
#   }

#   depends_on = [
#     helm_release.argocd,
#     kubectl_manifest.cluster_issuer
#   ]
# }

# # ============================================================================
# # Wait for ArgoCD to be fully ready
# # Gives ArgoCD time to start up and register CRDs before creating projects
# # ============================================================================
# resource "time_sleep" "wait_for_argocd" {
#   depends_on = [helm_release.argocd]

#   create_duration = "90s"  # Increased to ensure CRDs are registered
# }

# # Null resource to verify ArgoCD CRDs are available
# # This prevents race conditions when creating AppProject and Application resources
# # resource "null_resource" "verify_argocd_crds" {
# #   depends_on = [time_sleep.wait_for_argocd]

# #   provisioner "local-exec" {
# #     command = <<-EOT
# #       echo "Waiting for ArgoCD CRDs to be available..."
# #       for i in {1..30}; do
# #         if kubectl get crd appprojects.argoproj.io applications.argoproj.io 2>/dev/null; then
# #           echo "ArgoCD CRDs are available"
# #           exit 0
# #         fi
# #         echo "Waiting for CRDs... attempt $i/30"
# #         sleep 5
# #       done
# #       echo "ERROR: ArgoCD CRDs not available after 150 seconds"
# #       exit 1
# #     EOT
# #   }
# # }

# # ============================================================================
# # ArgoCD Project for Craftista
# # Projects provide logical grouping and access control for applications
# # Using kubectl_manifest for better CRD handling
# # ============================================================================
# resource "kubectl_manifest" "craftista_project" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: AppProject
#     metadata:
#       name: craftista
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#     spec:
#       description: Craftista Microservices Project

#       # Source Repositories - Which Git repositories can this project deploy from?
#       sourceRepos:
#         - https://github.com/akhileshmishrabiz/may-bootcamp.git
#         - '*'  # Allow all repos for flexibility (remove in production for security)

#       # Destination Clusters and Namespaces - Where can this project deploy?
#       destinations:
#         - server: https://kubernetes.default.svc
#           namespace: ${var.namespace}
#         - server: https://kubernetes.default.svc
#           namespace: craftista

#       # Cluster Resource Whitelist - Which cluster-scoped resources allowed?
#       clusterResourceWhitelist:
#         - group: ''
#           kind: Namespace
#         - group: rbac.authorization.k8s.io
#           kind: '*'

#       # Namespace Resource Whitelist - Allow all resources within namespace
#       namespaceResourceWhitelist:
#         - group: '*'
#           kind: '*'

#       # Orphaned Resources - Warn about resources deleted from Git
#       orphanedResources:
#         warn: true
#   YAML

#   # depends_on = [
#   #   null_resource.verify_argocd_crds
#   # ]
# }

# # # ============================================================================
# # # ArgoCD Application for Craftista Microservices
# # # This is the main application definition that tells ArgoCD what to deploy
# # # Using kubectl_manifest for better CRD handling
# # # ============================================================================
# resource "kubectl_manifest" "craftista_application" {
#   yaml_body = <<-YAML
#     apiVersion: argoproj.io/v1alpha1
#     kind: Application
#     metadata:
#       name: craftista-microservices
#       namespace: ${kubernetes_namespace.argocd.metadata[0].name}
#       finalizers:
#         - resources-finalizer.argocd.argoproj.io
#       labels:
#         app.kubernetes.io/name: craftista
#         app.kubernetes.io/instance: ${var.environment}
#     spec:
#       # Associate with the Craftista project
#       project: craftista

#       # Source Configuration - Where is the application manifest in Git?
#       source:
#         repoURL: https://github.com/akhileshmishrabiz/may-bootcamp.git
#         path: class28-29/microservices-on-k8s/k8s-menifest-adv
#         targetRevision: HEAD  # Track main/master branch

#       # Destination - Where should ArgoCD deploy the application?
#       destination:
#         server: https://kubernetes.default.svc
#         namespace: ${var.namespace}

#       # Sync Policy - How should ArgoCD keep cluster in sync with Git?
#       syncPolicy:
#         # Automated sync - ArgoCD automatically applies Git changes
#         automated:
#           prune: true      # Delete resources removed from Git
#           selfHeal: true   # Revert manual changes to match Git

#         # Additional sync options
#         syncOptions:
#           - CreateNamespace=true
#           - PrunePropagationPolicy=foreground
#           - PruneLast=true

#         # Retry configuration for failed syncs
#         retry:
#           limit: 5
#           backoff:
#             duration: 5s
#             factor: 2
#             maxDuration: 3m

#       # Ignore Differences - Prevent drift detection for controller-managed fields
#       ignoreDifferences:
#         - group: apps
#           kind: Deployment
#           managedFieldsManagers:
#             - kube-controller-manager

#       # Keep last 10 revisions for rollback
#       revisionHistoryLimit: 10
#   YAML

#   depends_on = [
#     kubectl_manifest.craftista_project
#   ]
# }

# # ============================================================================
# # Outputs
# # ============================================================================

# # ArgoCD server URL (accessible via browser)
# output "argocd_server_url" {
#   description = "ArgoCD Server URL"
#   value       = "https://argocd.${var.subdomain}.${var.domain_name}"
# }

# # Command to retrieve ArgoCD admin password
# output "argocd_admin_password_command" {
#   description = "Command to retrieve ArgoCD admin password"
#   value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
# }

# # ArgoCD login credentials info
# output "argocd_info" {
#   description = "ArgoCD access information"
#   value = {
#     url      = "https://argocd.${var.subdomain}.${var.domain_name}"
#     username = "admin"
#     password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
#     namespace = "argocd"
#   }
# }
