output "role_arn" {
  description = "IAM role ARN assumed by GitHub Actions."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name assumed by GitHub Actions."
  value       = aws_iam_role.this.name
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN used in the trust policy."
  value       = local.oidc_provider_arn
}

output "github_subject" {
  description = "Exact GitHub subject claim allowed by the trust policy."
  value       = local.github_subject
}
