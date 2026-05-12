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

  # Bootstrap role has no inline or managed policies.
  # Policies are added in the main EKS stack for specific workloads.
  managed_policy_arns = []
  inline_policy_json  = null

  tags = var.tags
}
