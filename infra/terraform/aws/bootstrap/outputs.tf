output "github_oidc_role_arn" {
  description = "ARN of the GitHub Actions IAM role. Set this in GitHub repository variables as AWS_GITHUB_OIDC_ROLE_ARN."
  value       = module.github_oidc_role.role_arn
}

output "github_oidc_role_name" {
  description = "Name of the GitHub Actions IAM role."
  value       = module.github_oidc_role.role_name
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider. Account-level resource (shared across all GitHub Actions workflows in this account)."
  value       = module.github_oidc_role.oidc_provider_arn
}

output "github_subject_claim" {
  description = "Exact subject claim allowed by the trust policy. Useful for debugging trust policy mismatches."
  value       = module.github_oidc_role.github_subject
}
