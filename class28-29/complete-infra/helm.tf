# Install AWS Load Balancer Controller using Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_load_balancer_controller.arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.eks_network.vpc_id
  }

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
    module.eks
  ]
}

# Install NGINX Ingress Controller using Helm
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = "4.11.3"

  create_namespace = true

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            # Use NLB instead of CLB
            "service.beta.kubernetes.io/aws-load-balancer-type"              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"            = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
            # Enable proxy protocol for real client IP preservation
            "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"    = "*"
          }
          externalTrafficPolicy = "Local"
        }
        config = {
          # Enable real IP forwarding
          "use-proxy-protocol"     = "true"
          "compute-full-forward-for" = "true"
          "use-forwarded-headers"  = "true"
        }
        metrics = {
          enabled = true
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.aws_load_balancer_controller,
    module.eks
  ]
}