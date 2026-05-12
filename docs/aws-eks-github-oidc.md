# AWS EKS + GitHub Actions OIDC

This path adds a cloud deployment option alongside the local kind + Keycloak lab. The goal is the same: short-lived identity, explicit trust, and minimal standing credentials.

## What Gets Created

- A dev VPC and a single EKS cluster.
- A GitHub OIDC provider for `https://token.actions.githubusercontent.com`.
- A GitHub Actions IAM role with a strict trust policy.
- An EKS access entry that lets the GitHub role reach the cluster after role assumption.
- Example workflows for Terraform plan, Terraform apply, and an optional EKS deploy.

## Trust Relationship

The IAM role trust policy is intentionally narrow:

- `aud` must equal `sts.amazonaws.com`
- `sub` must equal one exact GitHub subject

Branch-scoped example:

```text
repo:victorbecerragit/secure-multi-cluster-oidc-k8s:ref:refs/heads/main
```

Environment-scoped example:

```text
repo:victorbecerragit/secure-multi-cluster-oidc-k8s:environment:dev
```

This means a workflow from another repository, another branch, or another environment cannot assume the role.

## GitHub Workflow Permissions

Every workflow that uses OIDC needs:

```yaml
permissions:
  id-token: write
  contents: read
```

`id-token: write` allows the runner to request the GitHub OIDC token. `contents: read` is enough for checkout in this repo.

## AWS Bootstrap Steps

1. Choose the AWS account and region for the dev cluster.
2. Decide whether Terraform will create the GitHub OIDC provider or reuse an existing one.
3. Copy [infra/terraform/aws/environments/dev/terraform.tfvars.example](/home/victorbecerra/antigravity/kube-secure-oicd/infra/terraform/aws/environments/dev/terraform.tfvars.example) to a local `terraform.tfvars`.
4. Review the default inline CI policy in [infra/terraform/aws/environments/dev/main.tf](/home/victorbecerra/antigravity/kube-secure-oicd/infra/terraform/aws/environments/dev/main.tf) and remove any unused service actions before production use.
5. Apply Terraform locally once, then copy these outputs into GitHub repository variables:
   - `AWS_GITHUB_OIDC_ROLE_ARN`
   - `AWS_REGION`
   - `AWS_EKS_CLUSTER_NAME`

## Terraform and GitHub Actions Interaction

1. Terraform creates the GitHub-trusted IAM role and the EKS cluster.
2. GitHub Actions requests an OIDC token at runtime.
3. AWS STS exchanges that token for short-lived credentials on the IAM role.
4. Terraform workflows use those credentials for plan/apply.
5. The deploy workflow uses the same credentials to call `aws eks update-kubeconfig` and then `kubectl`.

## How EKS Authentication Works

After role assumption, GitHub Actions is still not automatically a Kubernetes admin. EKS access is granted separately through an access entry and policy association.

This scaffold uses an explicit EKS access entry for the GitHub role rather than relying on hidden `aws-auth` ConfigMap mutations. That keeps the trust chain visible during review:

- IAM role trust decides who can get AWS credentials.
- EKS access entries decide what that role can do against the Kubernetes API.

The default scaffold uses `AmazonEKSClusterAdminPolicy` so the end-to-end example is easy to validate. Narrow that to namespace-scoped or read-only policies once the bootstrap flow is proven out.

The AWS IAM side is now scaffolded with an inline service-scoped policy instead of `AdministratorAccess`. Managed policies remain optional and default to an empty list.

## Suggested Deployment Flow

1. Run Terraform locally for the dev environment.
2. Review outputs and set GitHub repository variables.
3. Open a pull request and let the plan workflow validate drift and syntax.
4. Merge to `main` or run the apply workflow manually.
5. Use the optional deploy workflow to apply a known-safe manifest.

## Files Added

- [infra/terraform/aws/modules/github-oidc-role/main.tf](/home/victorbecerra/antigravity/kube-secure-oicd/infra/terraform/aws/modules/github-oidc-role/main.tf)
- [infra/terraform/aws/modules/eks-cluster/main.tf](/home/victorbecerra/antigravity/kube-secure-oicd/infra/terraform/aws/modules/eks-cluster/main.tf)
- [infra/terraform/aws/environments/dev/main.tf](/home/victorbecerra/antigravity/kube-secure-oicd/infra/terraform/aws/environments/dev/main.tf)
- [/.github/workflows/terraform-aws-eks-plan.yml](/home/victorbecerra/antigravity/kube-secure-oicd/.github/workflows/terraform-aws-eks-plan.yml)
- [/.github/workflows/terraform-aws-eks-apply.yml](/home/victorbecerra/antigravity/kube-secure-oicd/.github/workflows/terraform-aws-eks-apply.yml)
- [/.github/workflows/deploy-aws-eks-example.yml](/home/victorbecerra/antigravity/kube-secure-oicd/.github/workflows/deploy-aws-eks-example.yml)
