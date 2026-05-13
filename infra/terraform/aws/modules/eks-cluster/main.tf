# Generate unique suffix for KMS alias to avoid conflicts on repeated applies
resource "random_id" "kms_alias_suffix" {
  byte_length = 4
}

locals {
  cluster_scope_access_entries = {
    for key, value in var.access_entries : key => value
    if value.access_scope_type == "cluster"
  }

  namespace_scope_access_entries = {
    for key, value in var.access_entries : key => value
    if value.access_scope_type == "namespace"
  }

  # Encryption config with unique KMS alias to prevent AlreadyExistsException
  # Only configure if create_cluster_encryption is true
  # eks module v20 expects an object or null (not a list)
  cluster_encryption_config = var.create_cluster_encryption ? {
    provider_key_arn = aws_kms_key.eks[0].arn
    resources        = ["secrets"]
  } : null
}

# KMS key for EKS cluster encryption
resource "aws_kms_key" "eks" {
  count = var.create_cluster_encryption ? 1 : 0

  description             = "KMS key for ${var.cluster_name} EKS cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-eks-key"
    }
  )
}

# Unique KMS alias with random suffix
resource "aws_kms_alias" "eks" {
  count = var.create_cluster_encryption ? 1 : 0

  name          = "alias/eks/${var.cluster_name}-${random_id.kms_alias_suffix.hex}"
  target_key_id = aws_kms_key.eks[0].key_id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                             = var.cluster_name
  cluster_version                          = var.kubernetes_version
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.subnet_ids
  cluster_endpoint_public_access           = var.cluster_endpoint_public_access
  cluster_endpoint_private_access          = var.cluster_endpoint_private_access
  enable_cluster_creator_admin_permissions = false
  cluster_encryption_config                = local.cluster_encryption_config

  eks_managed_node_groups = var.create_node_group ? {
    (var.node_group_name) = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  } : {}

  tags = var.tags
}

resource "aws_eks_access_entry" "this" {
  for_each = var.access_entries

  cluster_name      = module.eks.cluster_name
  principal_arn     = each.value.principal_arn
  kubernetes_groups = each.value.kubernetes_groups
  type              = "STANDARD"
}

# Security intent: bootstrap GitHub with one explicit EKS access policy instead of invisible aws-auth mutations.
resource "aws_eks_access_policy_association" "cluster_scope" {
  for_each = local.cluster_scope_access_entries

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.this]
}

resource "aws_eks_access_policy_association" "namespace_scope" {
  for_each = local.namespace_scope_access_entries

  cluster_name  = module.eks.cluster_name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type       = "namespace"
    namespaces = each.value.namespaces
  }

  depends_on = [aws_eks_access_entry.this]
}
