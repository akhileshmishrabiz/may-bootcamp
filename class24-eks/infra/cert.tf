
data "aws_route53_zone" "main" {
  name = var.domain_name
}

# Wait for AWS LB Controller to be ready
resource "time_sleep" "wait_for_lb_controller" {
  create_duration = "30s"
}

# ACM Certificate for Craftista Application
resource "aws_acm_certificate" "craftista" {
  domain_name       = "${var.subdomain}.${var.domain_name}"
  validation_method = "DNS"

  subject_alternative_names = [
    "catalogue.${var.subdomain}.${var.domain_name}",
    "voting.${var.subdomain}.${var.domain_name}",
    "recommendations.${var.subdomain}.${var.domain_name}",
    "*.${var.subdomain}.${var.domain_name}"
  ]

  tags = {
    Name        = "craftista-certificate"
    Environment = var.environment
    Application = var.application_name
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Route53 DNS validation records for ACM certificate
resource "aws_route53_record" "craftista_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.craftista.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "craftista" {
  certificate_arn         = aws_acm_certificate.craftista.arn
  validation_record_fqdns = [for record in aws_route53_record.craftista_cert_validation : record.fqdn]
}



# Route53 DNS validation records for ArgoCD ACM certificate
resource "aws_route53_record" "argocd_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.argocd.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}


# Ingress managed by Terraform for easy ALB lookup and Route53 mapping
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
      "alb.ingress.kubernetes.io/certificate-arn"     = aws_acm_certificate.craftista.arn
      "alb.ingress.kubernetes.io/healthcheck-path"    = "/"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "2"
      "alb.ingress.kubernetes.io/tags"                = "Environment=${var.environment},Application=${var.application_name},ManagedBy=Terraform"
    }
  }

  spec {
    ingress_class_name = "alb"

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
    aws_acm_certificate_validation.craftista,
    kubernetes_namespace.craftista,
    time_sleep.wait_for_lb_controller
  ]
}

# Wait for ALB to be created by the ingress controller (takes ~2-3 minutes)
resource "time_sleep" "wait_for_alb" {
  depends_on = [kubernetes_ingress_v1.craftista_ingress]

  create_duration = "180s"  # Wait 3 minutes for ALB creation
}

# Null resource to check if ALB exists before proceeding
resource "null_resource" "check_alb" {
  depends_on = [time_sleep.wait_for_alb]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking if ALB is created via kubectl..."
      for i in {1..10}; do
        ALB_HOST=$(kubectl get ingress craftista-ingress -n ${var.namespace} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

        if [ ! -z "$ALB_HOST" ]; then
          echo "ALB found: $ALB_HOST"
          exit 0
        fi

        echo "Waiting for ALB... attempt $i/10"
        sleep 30
      done
      echo "ALB not found after 10 attempts, but proceeding..."
    EOT
  }
}

# Data source to get the ALB created by the ingress
data "aws_lb" "craftista_alb" {
  tags = {
    "ingress.k8s.aws/stack" = "${var.namespace}/craftista-ingress"
  }

  depends_on = [null_resource.check_alb]
}

# Create wildcard Route53 record for all subdomains
resource "aws_route53_record" "wildcard" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "*.${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.craftista_alb.dns_name
    zone_id                = data.aws_lb.craftista_alb.zone_id
    evaluate_target_health = false
  }
}

# Create base subdomain record
resource "aws_route53_record" "main" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.craftista_alb.dns_name
    zone_id                = data.aws_lb.craftista_alb.zone_id
    evaluate_target_health = false
  }
}
