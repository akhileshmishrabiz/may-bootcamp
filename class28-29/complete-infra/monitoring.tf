# ============================================================================
# Monitoring Stack - Prometheus & Grafana
# ============================================================================
# This file deploys a complete monitoring solution using the kube-prometheus-stack
# which includes Prometheus, Grafana, Alertmanager, and various exporters

# Create namespace for monitoring components
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"

    labels = {
      name        = "monitoring"
      managed-by  = "terraform"
      environment = var.environment
    }
  }

  depends_on = [module.eks]
}

# Deploy kube-prometheus-stack (includes Prometheus, Grafana, Alertmanager, and exporters)
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "65.0.0"

  # Timeout increased for initial setup
  timeout = 600

  values = [
    yamlencode({
      # =======================
      # Prometheus Configuration
      # =======================
      prometheus = {
        prometheusSpec = {
          # Resource requests and limits
          resources = {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "1000m"
              memory = "2Gi"
            }
          }
          # Data retention
          retention = "15d"
          retentionSize = "10GB"

          # Storage configuration
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "20Gi"
                  }
                }
              }
            }
          }

          # Service monitor selector - monitor all services in craftista namespace
          serviceMonitorSelector = {}
          serviceMonitorNamespaceSelector = {}

          # Pod monitor selector
          podMonitorSelector = {}
          podMonitorNamespaceSelector = {}

          # Additional scrape configs for custom metrics
          additionalScrapeConfigs = []

          # Configure Prometheus to work with subpath
          externalUrl = "https://${var.subdomain}.${var.domain_name}/prometheus"
          routePrefix = "/"
        }

        # Prometheus service configuration
        service = {
          type = "ClusterIP"
          port = 9090
        }
      }

      # =======================
      # Grafana Configuration
      # =======================
      grafana = {
        enabled = true

        # Admin credentials
        adminPassword = "admin123"  # Change this in production!

        # Resource requests and limits
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }

        # Persistence for Grafana dashboards and data
        persistence = {
          enabled = true
          size    = "10Gi"
        }

        # Grafana service configuration
        service = {
          type = "ClusterIP"
          port = 80
        }

        # Disable default datasource creation (we'll use the sidecar)
        sidecar = {
          datasources = {
            enabled = true
            defaultDatasourceEnabled = true
          }
        }

        # Pre-configured dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [
              {
                name            = "default"
                orgId           = 1
                folder          = ""
                type            = "file"
                disableDeletion = false
                editable        = true
                options = {
                  path = "/var/lib/grafana/dashboards/default"
                }
              }
            ]
          }
        }

        # Import common dashboards
        dashboards = {
          default = {
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            kubernetes-pods = {
              gnetId     = 6417
              revision   = 1
              datasource = "Prometheus"
            }
            nginx-ingress = {
              gnetId     = 9614
              revision   = 1
              datasource = "Prometheus"
            }
          }
        }

        # Grafana ini configuration
        "grafana.ini" = {
          server = {
            domain   = "${var.subdomain}.${var.domain_name}"
            root_url = "https://${var.subdomain}.${var.domain_name}/grafana"
            serve_from_sub_path = true
          }
          analytics = {
            check_for_updates = false
          }
        }
      }

      # =======================
      # Alertmanager Configuration
      # =======================
      alertmanager = {
        enabled = true

        alertmanagerSpec = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          storage = {
            volumeClaimTemplate = {
              spec = {
                accessModes = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "5Gi"
                  }
                }
              }
            }
          }
        }
      }

      # =======================
      # Node Exporter
      # =======================
      nodeExporter = {
        enabled = true
      }

      # =======================
      # Kube State Metrics
      # =======================
      kubeStateMetrics = {
        enabled = true
      }

      # =======================
      # Default Rules
      # =======================
      defaultRules = {
        create = true
        rules = {
          alertmanager              = true
          etcd                      = true
          configReloaders           = true
          general                   = true
          k8s                       = true
          kubeApiserverAvailability = true
          kubeApiserverSlos         = true
          kubeControllerManager     = true
          kubelet                   = true
          kubeProxy                 = true
          kubePrometheusGeneral     = true
          kubePrometheusNodeRecording = true
          kubernetesApps            = true
          kubernetesResources       = true
          kubernetesStorage         = true
          kubernetesSystem          = true
          kubeSchedulerAlerting     = true
          kubeSchedulerRecording    = true
          kubeStateMetrics          = true
          network                   = true
          node                      = true
          nodeExporterAlerting      = true
          nodeExporterRecording     = true
          prometheus                = true
          prometheusOperator        = true
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.nginx_ingress
  ]
}

# ============================================================================
# Service Monitors for Craftista Applications
# ============================================================================
# These resources configure Prometheus to scrape metrics from your microservices

# ServiceMonitor for Frontend service
resource "kubectl_manifest" "frontend_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "frontend-metrics"
      namespace = var.craft_namespace
      labels = {
        app        = "frontend"
        release    = "kube-prometheus-stack"
        managed-by = "terraform"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "frontend"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_namespace.craftista
  ]
}

# ServiceMonitor for Catalogue service
resource "kubectl_manifest" "catalogue_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "catalogue-metrics"
      namespace = var.craft_namespace
      labels = {
        app        = "catalogue"
        release    = "kube-prometheus-stack"
        managed-by = "terraform"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "catalogue"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_namespace.craftista
  ]
}

# ServiceMonitor for Voting service
resource "kubectl_manifest" "voting_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "voting-metrics"
      namespace = var.craft_namespace
      labels = {
        app        = "voting"
        release    = "kube-prometheus-stack"
        managed-by = "terraform"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "voting"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/actuator/prometheus"
          interval = "30s"
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_namespace.craftista
  ]
}

# ServiceMonitor for Recommendation service
resource "kubectl_manifest" "recommendation_servicemonitor" {
  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "recommendation-metrics"
      namespace = var.craft_namespace
      labels = {
        app        = "recommendation"
        release    = "kube-prometheus-stack"
        managed-by = "terraform"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "recommendation"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_namespace.craftista
  ]
}

# ============================================================================
# Ingress for Grafana UI
# ============================================================================
resource "kubectl_manifest" "grafana_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "grafana-ingress"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
        "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
        "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      }
      labels = {
        app        = "grafana"
        managed-by = "terraform"
      }
    }
    spec = {
      ingressClassName = "nginx"
      tls = [
        {
          hosts = ["${var.subdomain}.${var.domain_name}"]
          secretName = "grafana-tls"
        }
      ]
      rules = [
        {
          host = "${var.subdomain}.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/grafana"
                pathType = "Prefix"
                backend = {
                  service = {
                    name = "kube-prometheus-stack-grafana"
                    port = {
                      number = 80
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.nginx_ingress
  ]
}

# ============================================================================
# Ingress for Prometheus UI (Optional - for debugging)
# ============================================================================
resource "kubectl_manifest" "prometheus_ingress" {
  yaml_body = yamlencode({
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
      name      = "prometheus-ingress"
      namespace = kubernetes_namespace.monitoring.metadata[0].name
      annotations = {
        "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
        "nginx.ingress.kubernetes.io/rewrite-target"     = "/$2"
        "nginx.ingress.kubernetes.io/use-regex"          = "true"
        "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
        "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      }
      labels = {
        app        = "prometheus"
        managed-by = "terraform"
      }
    }
    spec = {
      ingressClassName = "nginx"
      tls = [
        {
          hosts = ["${var.subdomain}.${var.domain_name}"]
          secretName = "prometheus-tls"
        }
      ]
      rules = [
        {
          host = "${var.subdomain}.${var.domain_name}"
          http = {
            paths = [
              {
                path     = "/prometheus(/|$)(.*)"
                pathType = "ImplementationSpecific"
                backend = {
                  service = {
                    name = "kube-prometheus-stack-prometheus"
                    port = {
                      number = 9090
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.nginx_ingress
  ]
}
