# GitHub Actions OIDC Templates

This directory contains documentation and templates for secretless CI/CD.

## Live Workflows

The active workflows are located in the [`.github/workflows/`](../.github/workflows/) directory:

*   [`deploy-manager.yml`](../.github/workflows/deploy-manager.yml): Deployment persona for production.
*   [`validate-workload.yml`](../.github/workflows/validate-workload.yml): Read-only validation persona.
*   [`terraform-aws-eks-plan.yml`](../.github/workflows/terraform-aws-eks-plan.yml): Terraform fmt/validate/plan on the AWS EKS dev environment using OIDC.
*   [`terraform-aws-eks-apply.yml`](../.github/workflows/terraform-aws-eks-apply.yml): Terraform apply on the AWS EKS dev environment using OIDC.
*   [`deploy-aws-eks-example.yml`](../.github/workflows/deploy-aws-eks-example.yml): Optional EKS deploy example after role assumption.

## Documentation

For a deep dive into how OIDC trust is established, see [**docs/ci-cd-oidc.md**](../docs/ci-cd-oidc.md).
For the AWS-specific Terraform and EKS flow, see [**docs/aws-eks-github-oidc.md**](../docs/aws-eks-github-oidc.md).
