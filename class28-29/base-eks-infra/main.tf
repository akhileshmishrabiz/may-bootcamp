# VPC and Network Configuration
module "eks_network" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0"  # Using v5 for AWS Provider v5 compatibility

  name = "${var.prefix}-${var.environment}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-south-1a", "ap-south-1b",  "ap-south-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true  #  Use a single NAT Gateway
  single_nat_gateway = true  # Keep costs low by using only one NAT Gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS cluster subnet discovery
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.prefix}-${var.environment}-cluster" = "shared"
    "kubernetes.io/role/elb"                                         = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.prefix}-${var.environment}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                                = "1"
  }
}

# EKS Cluster Configuration
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
