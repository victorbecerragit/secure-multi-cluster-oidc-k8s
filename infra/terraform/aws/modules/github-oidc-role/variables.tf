variable "role_name" {
  description = "IAM role name for GitHub Actions."
  type        = string
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repository."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "subject_type" {
  description = "Scope the trust policy to either a branch ref or a GitHub environment."
  type        = string
  default     = "branch"

  validation {
    condition     = contains(["branch", "environment"], var.subject_type)
    error_message = "subject_type must be either 'branch' or 'environment'."
  }
}

variable "subject_value" {
  description = "Branch name or environment name allowed to assume the role."
  type        = string
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider in this account. Set false if it already exists."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN when create_oidc_provider is false."
  type        = string
  default     = null
}

variable "managed_policy_arns" {
  description = "Managed IAM policies to attach to the role. Keep this list narrow."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline IAM policy JSON attached directly to the GitHub Actions role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to created IAM resources."
  type        = map(string)
  default     = {}
}
