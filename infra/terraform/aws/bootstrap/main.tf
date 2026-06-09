data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  role_name_prefixed = "${data.aws_caller_identity.current.account_id}-${var.role_name}"
}

# Use the reusable GitHub OIDC module from the central modules directory.
# This module handles:
# - GitHub OIDC provider creation (idempotent if already exists)
# - Trust policy scoped to the specified repo + branch/environment
# - IAM role with the correct assume role policy
module "github_oidc_role" {
  source = "../modules/github-oidc-role"

  role_name   = local.role_name_prefixed
  github_owner  = var.github_owner
  github_repo   = var.github_repo
  subject_type  = var.github_subject_type
  subject_value = var.github_subject_value

  create_oidc_provider = true

  # Bootstrap role must have identity-based permissions to run Terraform from CI.
  managed_policy_arns = var.managed_policy_arns
  inline_policy_json  = null

  tags = var.tags
}

# ----------------------------------------------------------------------------
# GitHub Actions deploy roles
#
# These roles are intentionally in the bootstrap layer, NOT in the environment
# layer. IAM roles are account-level identity infrastructure that must survive
# cluster create/destroy cycles. Defining them here ensures that:
#   - `terraform destroy` on the EKS environment never removes them
#   - The cluster-level EKS access entries simply reference the role ARNs
#   - Re-creating a cluster never requires re-importing or re-creating roles
#
# Trust policy: only eks:DescribeCluster on the named cluster. All kubectl
# permissions are enforced by Kubernetes RBAC (ClusterRole/RoleBinding).
# ----------------------------------------------------------------------------

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid       = "EksDescribeOnly"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:${data.aws_partition.current.partition}:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
  }
}

module "github_oidc_role_deploy_prod" {
  source = "../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-prod"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "prod"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = var.tags
}

module "github_oidc_role_deploy_staging" {
  source = "../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-staging"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "staging"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = var.tags
}

module "github_oidc_role_deploy_dev" {
  source = "../modules/github-oidc-role"

  role_name                  = "${var.name_prefix}-gha-eks-deploy-dev"
  github_owner               = var.github_owner
  github_repo                = var.github_repo
  subject_type               = "environment"
  subject_value              = "dev"
  create_oidc_provider       = false
  existing_oidc_provider_arn = module.github_oidc_role.oidc_provider_arn
  inline_policy_json         = data.aws_iam_policy_document.github_actions_deploy.json
  tags                       = var.tags
}

