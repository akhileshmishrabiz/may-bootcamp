# Karpenter Node Autoscaling Setup Guide

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
- [Configuration](#configuration)
- [NodePool Examples](#nodepool-examples)
- [Migration Guide](#migration-guide)
- [Monitoring & Observability](#monitoring--observability)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)

---

## Overview

### What is Karpenter?

**Karpenter** is an open-source, flexible, high-performance Kubernetes cluster autoscaler built for AWS. It automatically provisions right-sized compute resources based on the specific requirements of cluster workloads.

### Karpenter vs Cluster Autoscaler

| Feature | Karpenter | Cluster Autoscaler |
|---------|-----------|-------------------|
| **Provisioning Speed** | ~60 seconds | 3-5 minutes |
| **Node Selection** | Optimal instance type selection | Pre-defined ASG instance types |
| **Consolidation** | Automatic node consolidation | Manual |
| **Spot Instance Support** | Native, seamless | Limited |
| **Configuration** | Simple CRDs (NodePool) | Complex ASG configurations |
| **Cost Optimization** | Intelligent instance selection | Limited optimization |
| **Architecture** | Kubernetes-native | Cloud-specific |

### Why Use Karpenter?

✅ **Fast Provisioning**: Launches nodes in ~60 seconds
✅ **Cost Optimization**: Selects cheapest instances matching requirements
✅ **Spot Instance Support**: Seamlessly handles Spot interruptions
✅ **Flexible**: Provisions diverse instance types based on workload needs
✅ **Consolidation**: Automatically replaces nodes with cheaper options
✅ **Less Configuration**: No need to manage Auto Scaling Groups

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         EKS Cluster                          │
│                                                              │
│  ┌──────────────┐         ┌─────────────────────┐          │
│  │   Pending    │────────▶│  Karpenter          │          │
│  │   Pods       │         │  Controller         │          │
│  └──────────────┘         └─────────────────────┘          │
│                                    │                         │
│                                    ▼                         │
│                          ┌──────────────────┐               │
│                          │   NodePool CRD   │               │
│                          │  (Requirements)  │               │
│                          └──────────────────┘               │
│                                    │                         │
└────────────────────────────────────┼─────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │      AWS EC2 API               │
                    │  - Launch instances            │
                    │  - Spot/On-Demand selection    │
                    │  - Instance type selection     │
                    └────────────────────────────────┘
                                     │
                                     ▼
                    ┌────────────────────────────────┐
                    │    New EC2 Instances           │
                    │  (Automatically joins cluster) │
                    └────────────────────────────────┘
```

**How Karpenter Works:**

1. **Watches for unschedulable pods** in the cluster
2. **Evaluates NodePool requirements** (CPU, memory, labels, taints)
3. **Selects optimal EC2 instance types** based on cost and availability
4. **Provisions nodes directly** via EC2 API (no ASG needed)
5. **Consolidates nodes** by replacing with cheaper/smaller instances when possible
6. **Handles interruptions** for Spot instances gracefully

---

## Prerequisites

Before installing Karpenter, ensure:

- ✅ EKS cluster is running (v1.23+)
- ✅ AWS CLI configured
- ✅ kubectl configured for your cluster
- ✅ Helm 3.x installed
- ✅ Terraform (for IaC approach)
- ✅ IAM permissions to create roles and policies

**Current Cluster Info:**
- Cluster: `may25-dev-cluster`
- Region: `ap-south-1`
- Kubernetes Version: `1.31`

---

## Installation Methods

### Method 1: Terraform Installation (Recommended)

#### Step 1: Create Karpenter IAM Resources

Create `karpenter.tf`:

```hcl
# ============================================================================
# Karpenter Node Autoscaler
# ============================================================================

# Get current AWS account and partition info
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ============================================================================
# IAM Role for Karpenter Controller
# ============================================================================

resource "aws_iam_role" "karpenter_controller" {
  name = "${var.prefix}-${var.environment}-karpenter-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:karpenter:karpenter"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Policy for Karpenter Controller
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${var.prefix}-${var.environment}-karpenter-controller-policy"
  description = "IAM policy for Karpenter controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceAccessActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::image/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}::snapshot/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:subnet/*"
        ]
      },
      {
        Sid    = "AllowScopedEC2LaunchTemplateAccessActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "AllowScopedEC2InstanceActionsWithTags"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "AllowScopedResourceCreationTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:fleet/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        ]
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = [
              "RunInstances",
              "CreateFleet",
              "CreateLaunchTemplate"
            ]
          }
        }
      },
      {
        Sid    = "AllowScopedResourceTagging"
        Effect = "Allow"
        Action = "ec2:CreateTags"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.sh/nodepool" = "*"
          }
          ForAllValues:StringEquals = {
            "aws:TagKeys" = [
              "karpenter.sh/nodeclaim",
              "Name"
            ]
          }
        }
      },
      {
        Sid    = "AllowScopedDeletion"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:DeleteLaunchTemplate"
        ]
        Resource = [
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
          "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:launch-template/*"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
          }
        }
      },
      {
        Sid    = "AllowRegionalReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid      = "AllowSSMReadActions"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:${data.aws_partition.current.partition}:ssm:${var.aws_region}::parameter/aws/service/*"
      },
      {
        Sid    = "AllowPricingReadActions"
        Effect = "Allow"
        Action = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Sid    = "AllowInterruptionQueueActions"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter.arn
      },
      {
        Sid    = "AllowPassingInstanceRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = module.eks.eks_managed_node_groups["example"].iam_role_arn
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Action = "iam:CreateInstanceProfile"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"
        Action = "iam:TagInstanceProfile"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"    = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = var.aws_region
            "aws:RequestedRegion"                           = var.aws_region
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region" = var.aws_region
          }
        }
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  policy_arn = aws_iam_policy.karpenter_controller.arn
  role       = aws_iam_role.karpenter_controller.name
}

# ============================================================================
# SQS Queue for Spot Instance Interruption Handling
# ============================================================================

resource "aws_sqs_queue" "karpenter" {
  name                      = "${var.prefix}-${var.environment}-karpenter"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue_policy" "karpenter" {
  queue_url = aws_sqs_queue.karpenter.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InterruptionPolicy"
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter.arn
      }
    ]
  })
}

# ============================================================================
# EventBridge Rules for Interruption Handling
# ============================================================================

# Spot Instance Interruption
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${var.prefix}-${var.environment}-karpenter-spot-interruption"
  description = "Karpenter Spot Instance Interruption"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterSpotInterruptionQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

# Instance Rebalance Recommendation
resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${var.prefix}-${var.environment}-karpenter-rebalance"
  description = "Karpenter Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterRebalanceQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

# Instance State Change
resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${var.prefix}-${var.environment}-karpenter-instance-state-change"
  description = "Karpenter Instance State Change"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "KarpenterInstanceStateChangeQueueTarget"
  arn       = aws_sqs_queue.karpenter.arn
}

# ============================================================================
# Helm Release for Karpenter
# ============================================================================

resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = "1.0.1"  # Use latest stable version
  namespace  = "karpenter"

  create_namespace = true

  values = [
    yamlencode({
      settings = {
        clusterName       = module.eks.cluster_name
        clusterEndpoint   = module.eks.cluster_endpoint
        interruptionQueue = aws_sqs_queue.karpenter.name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
        }
      }
      controller = {
        resources = {
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }
      }
      # Enable native Spot interruption handling
      replicas = 2

      # Tolerations to run on any node
      tolerations = [
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      ]
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller,
    module.eks
  ]
}
```

#### Step 2: Apply Terraform Configuration

```bash
terraform init
terraform plan
terraform apply
```

---

### Method 2: Manual Helm Installation

#### Step 1: Set Environment Variables

```bash
export CLUSTER_NAME="may25-dev-cluster"
export AWS_REGION="ap-south-1"
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export KARPENTER_VERSION="1.0.1"
```

#### Step 2: Create IAM Role

```bash
# Create IAM role for Karpenter
eksctl create iamserviceaccount \
  --cluster="${CLUSTER_NAME}" \
  --namespace=karpenter \
  --name=karpenter \
  --role-name="${CLUSTER_NAME}-karpenter" \
  --attach-policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}" \
  --role-only \
  --approve
```

#### Step 3: Install Karpenter via Helm

```bash
helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace karpenter \
  --create-namespace \
  --set settings.clusterName="${CLUSTER_NAME}" \
  --set settings.clusterEndpoint="$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-karpenter" \
  --wait
```

#### Step 4: Verify Installation

```bash
kubectl get pods -n karpenter
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

---

## Configuration

### NodePool Configuration

NodePools define the constraints and requirements for nodes that Karpenter provisions.

#### Basic NodePool Example

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  # Template for node configuration
  template:
    spec:
      requirements:
        # Instance categories
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]

        # Instance types (flexible)
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large", "t3a.medium", "t3a.large"]

        # Architecture
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

        # Availability zones
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["ap-south-1a", "ap-south-1b", "ap-south-1c"]

      # Node taints
      taints: []

      # Node labels
      nodeClassRef:
        name: default

  # Limits
  limits:
    cpu: "100"
    memory: "200Gi"

  # Disruption settings
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h # 30 days
```

### EC2NodeClass Configuration

EC2NodeClass defines AWS-specific configuration for nodes.

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  # AMI Selection
  amiFamily: AL2023  # Amazon Linux 2023

  # AMI Selector (optional, for custom AMIs)
  # amiSelectorTerms:
  #   - id: ami-0123456789

  # Subnet discovery
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  # Security group discovery
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  # IAM Role (use existing node role)
  role: "example-eks-node-group-20251003132942673700000001"

  # User data (optional)
  userData: |
    #!/bin/bash
    echo "Custom user data here"

  # Block device mappings
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true

  # Metadata options
  metadataOptions:
    httpEndpoint: enabled
    httpProtocolIPv6: disabled
    httpPutResponseHopLimit: 2
    httpTokens: required  # IMDSv2

  # Tags
  tags:
    Environment: dev
    ManagedBy: karpenter
```

---

## NodePool Examples

### 1. Spot Instance NodePool (Cost Optimized)

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]

        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - "t3.medium"
            - "t3.large"
            - "t3a.medium"
            - "t3a.large"
            - "t2.medium"
            - "t2.large"

        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

      taints:
        - key: karpenter.sh/spot
          effect: NoSchedule

      nodeClassRef:
        name: default

  limits:
    cpu: "100"

  disruption:
    consolidationPolicy: WhenUnderutilized
    consolidateAfter: 30s
```

**To use this NodePool:**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: spot-workload
spec:
  tolerations:
    - key: karpenter.sh/spot
      operator: Exists
  nodeSelector:
    karpenter.sh/capacity-type: spot
  containers:
    - name: app
      image: nginx
```

### 2. GPU NodePool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]

        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - "g4dn.xlarge"
            - "g4dn.2xlarge"
            - "g5.xlarge"

        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]

      taints:
        - key: nvidia.com/gpu
          effect: NoSchedule

      nodeClassRef:
        name: gpu

  limits:
    cpu: "100"

---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: gpu
spec:
  amiFamily: AL2023
  role: "example-eks-node-group-20251003132942673700000001"

  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}"

  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true
```

### 3. ARM-based NodePool (Graviton)

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: arm
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand", "spot"]

        - key: node.kubernetes.io/instance-type
          operator: In
          values:
            - "t4g.medium"
            - "t4g.large"
            - "c7g.medium"
            - "c7g.large"

        - key: kubernetes.io/arch
          operator: In
          values: ["arm64"]

      nodeClassRef:
        name: default

  limits:
    cpu: "50"

  disruption:
    consolidationPolicy: WhenUnderutilized
```

### 4. High-Memory NodePool (Databases)

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: memory-optimized
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]

        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["r", "x"]  # Memory-optimized families

        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["5"]  # Generation 5 and newer

      taints:
        - key: workload-type
          value: "memory-intensive"
          effect: NoSchedule

      nodeClassRef:
        name: default

  limits:
    memory: "500Gi"
```

---

## Migration Guide

### Migrating from Cluster Autoscaler

#### Step 1: Prepare Cluster

1. **Tag Subnets** for Karpenter discovery:

```bash
aws ec2 create-tags \
  --resources subnet-00878213177c7e975 subnet-01ef9fe92aa3c59dc \
  --tags Key=karpenter.sh/discovery,Value=may25-dev-cluster
```

2. **Tag Security Groups**:

```bash
# Get node security group ID
NODE_SG=$(aws eks describe-cluster --name may25-dev-cluster \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

aws ec2 create-tags \
  --resources $NODE_SG \
  --tags Key=karpenter.sh/discovery,Value=may25-dev-cluster
```

#### Step 2: Deploy Karpenter

```bash
terraform apply -target=helm_release.karpenter
```

#### Step 3: Create NodePool

```bash
kubectl apply -f - <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["t3.medium", "t3.large"]
      nodeClassRef:
        name: default
  limits:
    cpu: "100"
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: "example-eks-node-group-20251003132942673700000001"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "may25-dev-cluster"
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "may25-dev-cluster"
EOF
```

#### Step 4: Test with Sample Workload

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: inflate
spec:
  replicas: 0
  selector:
    matchLabels:
      app: inflate
  template:
    metadata:
      labels:
        app: inflate
    spec:
      containers:
        - name: inflate
          image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
          resources:
            requests:
              cpu: 1
              memory: 1.5Gi
EOF

# Scale up
kubectl scale deployment inflate --replicas=10

# Watch Karpenter provision nodes
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Check nodes
kubectl get nodes -w

# Scale down
kubectl scale deployment inflate --replicas=0
```

#### Step 5: Remove Cluster Autoscaler

```bash
# Once Karpenter is working
kubectl delete deployment cluster-autoscaler -n kube-system
```

---

## Monitoring & Observability

### Prometheus Metrics

Karpenter exposes Prometheus metrics on port 8000:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: karpenter-metrics
  namespace: karpenter
spec:
  selector:
    app.kubernetes.io/name: karpenter
  ports:
    - port: 8000
      targetPort: 8000
```

**Key Metrics:**

- `karpenter_nodepools_usage` - NodePool resource usage
- `karpenter_nodes_created_total` - Total nodes created
- `karpenter_nodes_terminated_total` - Total nodes terminated
- `karpenter_pods_state` - Pod scheduling state
- `karpenter_interruption_actions_performed_total` - Interruption handling

### Grafana Dashboard

Import Karpenter dashboard (ID: `19624`) in Grafana:

```bash
# Add to monitoring.tf ServiceMonitor
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: karpenter
  namespace: karpenter
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: karpenter
  endpoints:
    - port: http-metrics
      interval: 30s
EOF
```

### Logging

```bash
# View Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Filter for specific events
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep "launched node"
```

---

## Best Practices

### 1. **Use Multiple NodePools**

Create separate NodePools for different workload types:
- General workloads (on-demand)
- Batch jobs (spot)
- Databases (memory-optimized)
- ML workloads (GPU)

### 2. **Set Resource Requests**

Always set CPU/memory requests on pods:

```yaml
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "1"
    memory: "1Gi"
```

### 3. **Use Pod Disruption Budgets**

Protect critical workloads:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: frontend
```

### 4. **Configure Consolidation**

Enable node consolidation for cost savings:

```yaml
disruption:
  consolidationPolicy: WhenUnderutilized
  consolidateAfter: 30s
```

### 5. **Set Expiration**

Automatically expire old nodes:

```yaml
disruption:
  expireAfter: 168h  # 7 days
```

### 6. **Use Spot Wisely**

- Use Spot for fault-tolerant workloads
- Set appropriate tolerations
- Consider using on-demand for critical services

### 7. **Monitor Costs**

- Use AWS Cost Explorer with tags
- Track `karpenter.sh/nodepool` tag
- Monitor `karpenter_nodepools_usage` metric

### 8. **Security Hardening**

- Use IMDSv2 (enforced in EC2NodeClass)
- Encrypt EBS volumes
- Use minimal IAM permissions
- Enable pod security standards

---

## Troubleshooting

### Pods Not Scheduling

```bash
# Check pod events
kubectl describe pod <pod-name>

# Check NodePool
kubectl get nodepool
kubectl describe nodepool default

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=100
```

**Common Issues:**
- NodePool limits reached
- No instance types match requirements
- Subnet or security group misconfigured
- IAM permissions missing

### Nodes Not Launching

```bash
# Check EC2NodeClass
kubectl get ec2nodeclass
kubectl describe ec2nodeclass default

# Verify IAM role
aws iam get-role --role-name may25-dev-ebs-csi-driver

# Check subnet tags
aws ec2 describe-subnets --filters "Name=tag:karpenter.sh/discovery,Values=may25-dev-cluster"
```

### High Costs

```bash
# Check node utilization
kubectl top nodes

# Review NodePool limits
kubectl get nodepool -o yaml

# Check consolidation settings
kubectl describe nodepool default | grep -A5 disruption
```

### Spot Interruptions

```bash
# Check SQS queue
aws sqs get-queue-attributes \
  --queue-url <queue-url> \
  --attribute-names ApproximateNumberOfMessages

# Check EventBridge rules
aws events list-rules --name-prefix karpenter

# Check Karpenter logs for interruption handling
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep interruption
```

---

## Cost Optimization

### 1. **Use Spot Instances**

70-90% cost savings:

```yaml
requirements:
  - key: karpenter.sh/capacity-type
    operator: In
    values: ["spot", "on-demand"]  # Fallback to on-demand
```

### 2. **Enable Consolidation**

Automatically replace nodes with cheaper alternatives:

```yaml
disruption:
  consolidationPolicy: WhenUnderutilized
  consolidateAfter: 30s
```

### 3. **Use Graviton (ARM)**

Up to 40% cost savings:

```yaml
requirements:
  - key: kubernetes.io/arch
    operator: In
    values: ["amd64", "arm64"]
```

### 4. **Flexible Instance Types**

Let Karpenter choose cheapest:

```yaml
requirements:
  - key: node.kubernetes.io/instance-type
    operator: In
    values: ["t3.medium", "t3.large", "t3a.medium", "t3a.large", "t2.medium"]
```

### 5. **Set Appropriate TTLs**

Remove idle nodes quickly:

```yaml
disruption:
  consolidationPolicy: WhenEmpty
  consolidateAfter: 30s
```

### 6. **Right-Size Requests**

Avoid over-provisioning:

```yaml
resources:
  requests:
    cpu: "100m"      # Not 1 CPU
    memory: "128Mi"  # Not 1 GiB
```

### Cost Tracking

```bash
# Tag resources for cost tracking
tags:
  Environment: dev
  Team: platform
  CostCenter: engineering
  ManagedBy: karpenter
  NodePool: default
```

Use AWS Cost Explorer:
- Filter by tag: `karpenter.sh/nodepool`
- Compare Spot vs On-Demand
- Track monthly trends

---

## Quick Reference Commands

```bash
# Check Karpenter status
kubectl get pods -n karpenter
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# List NodePools
kubectl get nodepool
kubectl describe nodepool <name>

# List EC2NodeClasses
kubectl get ec2nodeclass
kubectl describe ec2nodeclass <name>

# Check node provisioning
kubectl get nodes -L karpenter.sh/nodepool -L karpenter.sh/capacity-type

# View node claims
kubectl get nodeclaim

# Check metrics
kubectl port-forward -n karpenter svc/karpenter 8000:8000
curl http://localhost:8000/metrics

# Force consolidation (drain and replace)
kubectl delete node <node-name>
```

---

## Additional Resources

- **Official Docs**: https://karpenter.sh/docs/
- **AWS Workshop**: https://www.eksworkshop.com/docs/autoscaling/compute/karpenter/
- **GitHub**: https://github.com/aws/karpenter
- **Community**: https://kubernetes.slack.com (#karpenter)
- **Cost Calculator**: https://instances.vantage.sh/

---

**Last Updated**: 2025-10-07
**Karpenter Version**: v1.0.1
**EKS Version**: 1.31
