
data "aws_route53_zone" "main" {
  name = var.domain_name
}


# Wait for AWS LB Controller to be ready
resource "time_sleep" "wait_for_lb_controller" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "30s"
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
  depends_on = [
    helm_release.cert_manager,
    kubernetes_config_map.cert_manager_ready
  ]

  create_duration = "30s"
}

# Create ClusterIssuer for Let's Encrypt with DNS-01 validation using Route53
resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: ${var.cert_email}
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - selector:
            dnsZones:
              - "${var.domain_name}"
          dns01:
            route53:
              region: ${var.aws_region}
              hostedZoneID: ${data.aws_route53_zone.main.zone_id}
  YAML

  depends_on = [
    time_sleep.wait_for_cert_manager,
    helm_release.nginx_ingress
  ]
}

# Create Certificate resource explicitly (before ingress) - using wildcard
resource "kubectl_manifest" "craftista_certificate" {
  yaml_body = <<-YAML
    apiVersion: cert-manager.io/v1
    kind: Certificate
    metadata:
      name: craftista-tls-cert
      namespace: ${var.namespace}
    spec:
      secretName: craftista-tls-secret
      issuerRef:
        name: letsencrypt-prod
        kind: ClusterIssuer
      dnsNames:
        - "*.${var.subdomain}.${var.domain_name}"
        - ${var.subdomain}.${var.domain_name}
  YAML

  depends_on = [
    kubectl_manifest.cluster_issuer,
    kubernetes_namespace.craftista
  ]
}

# Ingress managed by Terraform using NGINX Ingress Controller
resource "kubernetes_ingress_v1" "craftista_ingress" {
  metadata {
    name      = "craftista-ingress"
    namespace = var.namespace

    annotations = {
      # SSL redirect enabled - all HTTP traffic will redirect to HTTPS
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    # TLS configuration using cert-manager issued certificate
    tls {
      hosts = [
        "${var.subdomain}.${var.domain_name}",
        "catalogue.${var.subdomain}.${var.domain_name}",
        "voting.${var.subdomain}.${var.domain_name}",
        "recommendations.${var.subdomain}.${var.domain_name}"
      ]
      secret_name = "craftista-tls-secret"
    }

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
    kubectl_manifest.craftista_certificate,
    kubectl_manifest.cluster_issuer,
    helm_release.nginx_ingress,
    kubernetes_namespace.craftista
  ]
}

# Wait for NLB to be created by NGINX ingress controller
resource "time_sleep" "wait_for_nlb" {
  depends_on = [helm_release.nginx_ingress]

  create_duration = "60s"  # Wait 1 minute for NLB creation
}

# Data source to get NGINX Ingress Controller LoadBalancer service
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }

  depends_on = [time_sleep.wait_for_nlb]
}

# Create wildcard Route53 record for all subdomains pointing to NLB
resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  records = [data.kubernetes_service.nginx_ingress.status.0.load_balancer.0.ingress.0.hostname]
}

# Create base subdomain record pointing to NLB
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300

  records = [data.kubernetes_service.nginx_ingress.status.0.load_balancer.0.ingress.0.hostname]
}
