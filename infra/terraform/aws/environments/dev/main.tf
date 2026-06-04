provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_partition" "current" {}

data "aws_caller_identity" "current" {}

locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, 2)
  role_prefix = "${var.name_prefix}-"

  common_tags = merge({
    Project     = "secure-multi-cluster-oidc-k8s"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }, var.tags)
}

# Security intent: keep the GitHub role scoped to services this scaffold actually provisions instead of using AdministratorAccess.
data "aws_iam_policy_document" "github_actions_ci" {
  statement {
    sid = "EksManagement"
    actions = [
      "eks:AssociateAccessPolicy",
      "eks:CreateAccessEntry",
      "eks:CreateCluster",
      "eks:CreateNodegroup",
      "eks:DeleteAccessEntry",
      "eks:DeleteCluster",
      "eks:DeleteNodegroup",
      "eks:DescribeAccessEntry",
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "eks:DisassociateAccessPolicy",
      "eks:ListAccessEntries",
      "eks:ListAssociatedAccessPolicies",
      "eks:ListClusters",
      "eks:ListNodegroups",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:UpdateNodegroupConfig",
      "eks:UpdateNodegroupVersion"
    ]
    resources = ["*"]
  }

  statement {
    sid = "IamForEksAndOidc"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AttachRolePolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreateRole",
      "iam:CreateServiceLinkedRole",
      "iam:DeleteOpenIDConnectProvider",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetOpenIDConnectProvider",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListOpenIDConnectProviders",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:TagRole",
      "iam:UntagOpenIDConnectProvider",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com",
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_prefix}*"
    ]
  }

  statement {
    sid = "Ec2VpcAndNetworking"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:Describe*",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateAddress",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AutoscalingAndLaunchTemplates"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DeleteTags",
      "autoscaling:Describe*",
      "autoscaling:SuspendProcesses",
      "autoscaling:UpdateAutoScalingGroup",
      "ec2:CreateLaunchTemplate",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LoggingAndKms"
    actions = [
      "kms:CreateAlias",
      "kms:CreateGrant",
      "kms:CreateKey",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:ListAliases",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource"
    ]
    resources = ["*"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.name_prefix}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, index)]
  public_subnets  = [for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, index + 8)]

  enable_nat_gateway = false
  single_nat_gateway = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  tags = local.common_tags
}

module "github_oidc_role" {
  source = "../../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-terraform"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = var.github_subject_type
  subject_value              = var.github_subject_value
  create_oidc_provider       = var.create_github_oidc_provider
  existing_oidc_provider_arn = var.existing_github_oidc_provider_arn
  managed_policy_arns        = var.github_actions_managed_policy_arns
  inline_policy_json         = data.aws_iam_policy_document.github_actions_ci.json
  tags                       = local.common_tags
}

# Security intent: the deploy role only needs DescribeCluster to build a kubeconfig.
# All kubectl permissions are controlled by Kubernetes RBAC via the github:ci-deployers group.
data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "EksDescribeOnly"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
  }
}

# Separate GitHub OIDC role for Kubernetes deployment only.
# This role CANNOT modify infrastructure – it is scoped purely to kubectl apply operations
# through Kubernetes RBAC, keeping infra provisioning and app deployment as separate identities.
module "github_oidc_role_deploy_prod" {
  source = "../../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-prod"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "prod"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = local.common_tags
}

# Separate GitHub OIDC role for Kubernetes deployment only.
# This role CANNOT modify infrastructure – it is scoped purely to kubectl apply operations
# through Kubernetes RBAC, keeping infra provisioning and app deployment as separate identities.
module "github_oidc_role_deploy_staging" {
  source = "../../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-staging"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "staging"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = local.common_tags
}

# Separate GitHub OIDC role for Kubernetes deployment only.
module "github_oidc_role_deploy_dev" {
  source = "../../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-dev"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "dev"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = local.common_tags
}

# Separate GitHub OIDC role for ECR build and push operations.
# Scoped specifically for container image management in CI/CD workflows.
module "github_oidc_role_build" {
  source = "../../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-ecr-build"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "branch"
  subject_value              = "main"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  managed_policy_arns        = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"]
  tags                       = local.common_tags
}

module "eks_cluster" {
  source = "../../modules/eks-cluster"

  cluster_name        = var.cluster_name
  kubernetes_version  = var.kubernetes_version
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  access_entries = {
    # Infra role: full cluster admin for Terraform-managed provisioning
    github_actions_terraform = {
      principal_arn     = module.github_oidc_role.role_arn
      kubernetes_groups = ["github:terraform-admins"]
      policy_arn        = var.github_actions_eks_access_policy_arn
      access_scope_type = var.github_actions_eks_access_scope_type
      namespaces        = var.github_actions_eks_access_namespaces
    }
    # Deploy roles: group-only entries; permissions are managed by Kubernetes RBAC (ClusterRole/RoleBinding)
    github_actions_deploy_prod = {
      principal_arn     = module.github_oidc_role_deploy_prod.role_arn
      kubernetes_groups = ["github:ci-deployers"]
    }
    github_actions_deploy_staging = {
      principal_arn     = module.github_oidc_role_deploy_staging.role_arn
      kubernetes_groups = ["github:ci-deployers"]
    }
    github_actions_deploy_dev = {
      principal_arn     = module.github_oidc_role_deploy_dev.role_arn
      kubernetes_groups = ["github:ci-deployers"]
    }
  }

  tags = local.common_tags
}
