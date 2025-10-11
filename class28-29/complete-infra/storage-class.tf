# ============================================================================
# EBS CSI Storage Classes
# ============================================================================
# Create storage classes using the EBS CSI driver for persistent volumes

# GP3 Storage Class (Recommended - faster and cheaper than gp2)
resource "kubectl_manifest" "gp3_storage_class" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-gp3"
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
      labels = {
        managed-by = "terraform"
      }
    }
    provisioner = "ebs.csi.aws.com"
    parameters = {
      type      = "gp3"
      encrypted = "true"
      # GP3 allows custom IOPS and throughput
      iops       = "3000"   # Default: 3000, Max: 16000
      throughput = "125"    # Default: 125 MiB/s, Max: 1000 MiB/s
    }
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
  })

  depends_on = [module.eks]
}

# GP2 Storage Class (Legacy, for compatibility)
resource "kubectl_manifest" "gp2_csi_storage_class" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-gp2"
      labels = {
        managed-by = "terraform"
      }
    }
    provisioner = "ebs.csi.aws.com"
    parameters = {
      type      = "gp2"
      encrypted = "true"
    }
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
  })

  depends_on = [module.eks]
}

# IO2 Storage Class (High performance for databases)
resource "kubectl_manifest" "io2_storage_class" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-io2"
      labels = {
        managed-by = "terraform"
      }
    }
    provisioner = "ebs.csi.aws.com"
    parameters = {
      type = "io2"
      iops = "10000"  # Provisioned IOPS
      encrypted = "true"
    }
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    reclaimPolicy        = "Delete"
  })

  depends_on = [module.eks]
}

# Retain Policy Storage Class (for critical data)
resource "kubectl_manifest" "gp3_retain_storage_class" {
  yaml_body = yamlencode({
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "ebs-gp3-retain"
      labels = {
        managed-by = "terraform"
      }
    }
    provisioner = "ebs.csi.aws.com"
    parameters = {
      type      = "gp3"
      encrypted = "true"
    }
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    reclaimPolicy        = "Retain"  # Keep the volume even after PVC deletion
  })

  depends_on = [module.eks]
}
