variable "aws_region" {
  description = "AWS region for the bootstrap infrastructure."
  type        = string
  default     = "us-east-1"
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_subject_type" {
  description = "Scope of the GitHub Actions trust policy: 'branch' or 'environment'."
  type        = string
  default     = "branch"

  validation {
    condition     = contains(["branch", "environment"], var.github_subject_type)
    error_message = "github_subject_type must be either 'branch' or 'environment'."
  }
}

variable "github_subject_value" {
  description = "Branch name or environment name allowed to assume the GitHub Actions role."
  type        = string
  default     = "main"
}

variable "role_name" {
  description = "IAM role name for GitHub Actions CI/CD."
  type        = string
  default     = "github-actions-oidc-role"
}

variable "managed_policy_arns" {
  description = "Managed IAM policy ARNs attached to the bootstrap GitHub Actions role."
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project     = "secure-multi-cluster-oidc-k8s"
    Component   = "bootstrap"
    ManagedBy   = "Terraform"
  }
}
