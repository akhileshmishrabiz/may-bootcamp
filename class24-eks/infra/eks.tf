## FOR CLASS 21-23 #####
# module "eks" {
#   source  = "terraform-aws-modules/eks/aws"
#   version = "~> 20.0"  # Using v20 to maintain aws-auth compatibility
#   # vpc cni addon issue was fixed in v21 onwards
#   # uncomment below and comme above to mis managed group creation issue
#   # version = "~> 21.0" and for that 
#   # cluster_version will become kubernetes_version
#   # cluster_name will become name

#   cluster_name    = "${var.prefix}-${var.environment}-cluster"
#   cluster_version = "1.31"  # Latest stable version with good support

#   bootstrap_self_managed_addons = false
#   cluster_addons = {
#     coredns                = {}
#     eks-pod-identity-agent = {}
#     kube-proxy             = {}
#     vpc-cni                = {}
#   }

#   # Optional
#   cluster_endpoint_public_access = true

#   # Optional: Adds the current caller identity as an administrator via cluster access entry
#   enable_cluster_creator_admin_permissions = true

#   vpc_id     = module.eks_network.vpc_id
#   subnet_ids = module.eks_network.private_subnets

#   # EKS Managed Node Group(s)
#   eks_managed_node_group_defaults = {
#     instance_types = ["t3.medium", "t3.micro"]
#   }

#   eks_managed_node_groups = {
#     example = {
#       # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
#       ami_type       = "AL2023_x86_64_STANDARD"
#       instance_types = ["t3.medium"]

#       min_size     = 1
#       max_size     = 3
#       desired_size = 2
#     }
#   }

#   tags = {
#     Environment = var.environment
#     Terraform   = "true"
#     repo        = "may-bootcamp"
#   }
# }




##### For class 24 #####

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name    = "${var.prefix}-${var.environment}-cluster"
  kubernetes_version = "1.31"  # Latest stable version with good support

  addons = {
    coredns                = {}
    kube-proxy             = {}
    vpc-cni                = {
      before_compute = true
    }
    "aws-ebs-csi-driver"  = {}
  }

  # Optional
  endpoint_public_access = true
  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.eks_network.vpc_id
  subnet_ids = module.eks_network.private_subnets

  # EKS will automatically create an access entry for the IAM role(s) used by managed node group(s) and Fargate profile(s). 
  authentication_mode = "API_AND_CONFIG_MAP"
  eks_managed_node_groups = {
    example = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  tags = {
    Environment = var.environment
    Terraform   = "true"
    repo        = "may-bootcamp"
  }
}