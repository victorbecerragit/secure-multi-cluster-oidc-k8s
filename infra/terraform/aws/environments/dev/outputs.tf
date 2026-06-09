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

output "github_deploy_prod_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions for production deployments."
  value       = data.aws_iam_role.github_oidc_role_deploy_prod.arn
}

output "github_deploy_staging_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions for staging deployments."
  value       = data.aws_iam_role.github_oidc_role_deploy_staging.arn
}

output "github_deploy_dev_role_arn" {
  description = "IAM role ARN assumed by GitHub Actions for dev deployments."
  value       = data.aws_iam_role.github_oidc_role_deploy_dev.arn
}

output "github_build_role_arn" {
  description = "ECR build role ARN."
  value       = module.github_oidc_role_build.role_arn
}