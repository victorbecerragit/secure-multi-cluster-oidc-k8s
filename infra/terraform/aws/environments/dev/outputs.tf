output "aws_region" {
  description = "AWS region used by the dev environment."
  value       = var.aws_region
}

output "cluster_name" {
  description = "Dev EKS cluster name."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Dev EKS cluster endpoint."
  value       = module.eks_cluster.cluster_endpoint
}

output "github_actions_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions."
  value       = module.github_oidc_role.role_arn
}

output "github_oidc_provider_arn" {
  description = "OIDC provider ARN trusted by the GitHub Actions role."
  value       = module.github_oidc_role.oidc_provider_arn
}

output "github_subject" {
  description = "Exact GitHub subject claim allowed to assume the CI role."
  value       = module.github_oidc_role.github_subject
}
