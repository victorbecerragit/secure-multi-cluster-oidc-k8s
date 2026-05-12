variable "aws_region" {
  description = "AWS region for the dev environment."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to AWS resource names."
  type        = string
  default     = "secure-mc"
}

variable "cluster_name" {
  description = "Name of the dev EKS cluster."
  type        = string
  default     = "secure-dev-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the dev EKS cluster."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the dev VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "github_owner" {
  description = "GitHub owner used in the trust policy."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository used in the trust policy."
  type        = string
}

variable "github_subject_type" {
  description = "Use 'branch' or 'environment' for the GitHub trust scope."
  type        = string
  default     = "branch"

  validation {
    condition     = contains(["branch", "environment"], var.github_subject_type)
    error_message = "github_subject_type must be either 'branch' or 'environment'."
  }
}

variable "github_subject_value" {
  description = "Branch name or environment name allowed to assume the CI role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider in this account."
  type        = bool
  default     = true
}

variable "existing_github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when creation is disabled."
  type        = string
  default     = null
}

variable "github_actions_managed_policy_arns" {
  description = "Managed IAM policies attached to the GitHub Actions role."
  type        = list(string)
  default     = []
}

variable "github_actions_eks_access_policy_arn" {
  description = "EKS cluster access policy granted to the GitHub Actions role."
  type        = string
  default     = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

variable "github_actions_eks_access_scope_type" {
  description = "EKS access scope type for the GitHub Actions role."
  type        = string
  default     = "cluster"

  validation {
    condition     = contains(["cluster", "namespace"], var.github_actions_eks_access_scope_type)
    error_message = "github_actions_eks_access_scope_type must be 'cluster' or 'namespace'."
  }
}

variable "github_actions_eks_access_namespaces" {
  description = "Namespaces allowed when github_actions_eks_access_scope_type is namespace."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "Instance types for the dev node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count for the dev node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count for the dev node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count for the dev node group."
  type        = number
  default     = 3
}

variable "tags" {
  description = "Additional tags for the dev environment."
  type        = map(string)
  default     = {}
}
