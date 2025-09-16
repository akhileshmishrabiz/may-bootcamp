
data "aws_route53_zone" "main" {
  name = var.domain_name
}


# Install cert-manager using Helm
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.14.4"
  
  create_namespace = true
  
  set {
    name  = "installCRDs"
    value = "true"
  }
  
  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "certmanagersa"
  }
  
  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.cert_manager.arn
        }
      }
      securityContext = {
        fsGroup = 1001
      }
      webhook = {
        securePort = 10250
      }
    })
  ]
  
  depends_on = [
    aws_iam_role_policy_attachment.cert_manager
  ]
}

# Wait for cert-manager to be ready
resource "kubernetes_config_map" "cert_manager_ready" {
  metadata {
    name      = "cert-manager-ready"
    namespace = "cert-manager"
  }

  data = {
    ready = "true"
  }

  depends_on = [helm_release.cert_manager]
}

# Add a delay to ensure CRDs are available
resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]

  create_duration = "30s"
}

# Create ClusterIssuer for Let's Encrypt (Production)
resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.cert_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            http01 = {
              ingress = {
                class = "alb"
              }
            }
          }
        ]
      }
    }
  }

  depends_on = [
    time_sleep.wait_for_cert_manager
  ]
}

# Create a Certificate resource for the domains
resource "kubernetes_manifest" "craftista_certificate" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "craftista-tls-cert"
      namespace = var.namespace
    }
    spec = {
      secretName = "craftista-tls-secret"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "${var.subdomain}.${var.domain_name}",
        "catalogue.${var.subdomain}.${var.domain_name}",
        "voting.${var.subdomain}.${var.domain_name}",
        "recommendations.${var.subdomain}.${var.domain_name}"
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.cluster_issuer
  ]
}

resource "kubernetes_ingress_v1" "craftista_ingress" {
  metadata {
    name      = "craftista-ingress"
    namespace = var.namespace
    
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"         = "ip"
      "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"        = "443"
      "alb.ingress.kubernetes.io/healthcheck-path"    = "/"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
      "alb.ingress.kubernetes.io/tags"                = "Environment=${var.environment},Application=${var.application_name},ManagedBy=Terraform"
      # cert-manager annotation for automatic certificate
      "cert-manager.io/cluster-issuer"                = "letsencrypt-prod"
    }
  }
  
  spec {
    ingress_class_name = "alb"
    
    # TLS configuration using cert-manager certificate
    tls {
      hosts = [
        "${var.subdomain}.${var.domain_name}",
        "catalogue.${var.subdomain}.${var.domain_name}",
        "voting.${var.subdomain}.${var.domain_name}",
        "recommendations.${var.subdomain}.${var.domain_name}"
      ]
      secret_name = "craftista-tls-secret"
    }
    # catalogue
    # Main frontend
    rule {
      host = "${var.subdomain}.${var.domain_name}"
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "frontend"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    
    # Catalogue service
    rule {
      host = "catalogue.${var.subdomain}.${var.domain_name}"
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "catalogue"
              port {
                number = 5000
              }
            }
          }
        }
      }
    }
    
    # Voting service
    rule {
      host = "voting.${var.subdomain}.${var.domain_name}"
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "voting"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
    
    # Recommendations service
    rule {
      host = "recommendations.${var.subdomain}.${var.domain_name}"
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = "recco"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [ 
    kubernetes_manifest.cluster_issuer,
    kubernetes_manifest.craftista_certificate
    ]
}


# # Data source to get the ALB created by the ingress
# data "aws_lb" "craftista_alb" {
#   tags = {
#     "ingress.k8s.aws/stack" = "${var.namespace}/craftista-ingress"
#   }

#   depends_on = [kubernetes_ingress_v1.craftista_ingress]
# }

# # Create wildcard Route53 record for all subdomains
# resource "aws_route53_record" "wildcard" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "*.${var.subdomain}.${var.domain_name}"
#   type    = "A"

#   alias {
#     name                   = data.aws_lb.craftista_alb.dns_name
#     zone_id                = data.aws_lb.craftista_alb.zone_id
#     evaluate_target_health = false
#   }
# }

# # Create base subdomain record
# resource "aws_route53_record" "main" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "${var.subdomain}.${var.domain_name}"
#   type    = "A"

#   alias {
#     name                   = data.aws_lb.craftista_alb.dns_name
#     zone_id                = data.aws_lb.craftista_alb.zone_id
#     evaluate_target_health = false
#   }
# }