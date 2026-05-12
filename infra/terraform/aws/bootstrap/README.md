# AWS Bootstrap: GitHub Actions OIDC

This layer solves the **chicken-and-egg problem** in GitHub Actions CI/CD.

## The Problem

When provisioning AWS infrastructure via GitHub Actions, the workflow needs to authenticate to AWS. The standard approach is to use OIDC federation:

```
GitHub Actions Workflow → exchange OIDC token → AWS STS → assume IAM role
```

However, the IAM role is defined in the main Terraform stack (`../environments/dev/`), which the workflow itself would deploy. This creates a circular dependency: the workflow can't run until the infrastructure is deployed, but the infrastructure can't be deployed until the workflow has permission to run.

## The Solution

Create a separate, lightweight bootstrap stack that:
1. Creates the GitHub OIDC provider (account-level, one-time setup)
2. Creates a minimal GitHub Actions IAM role with a trust policy
3. Outputs the role ARN for GitHub repository secrets
4. Can be applied **locally** before any workflows run

Once the bootstrap role exists, the main EKS stack can be deployed via the workflow with proper OIDC authentication.

## Architecture

```
┌─────────────────────────────────────────┐
│  Local: Bootstrap (one-time)            │
│  ├─ GitHub OIDC provider (account)      │
│  └─ GitHub Actions IAM role (minimal)   │
└────────────┬────────────────────────────┘
             │
             ▼ Output: role ARN → GitHub repo secret
┌─────────────────────────────────────────┐
│  CI/CD: Workflow (on push to main)       │
│  ├─ Assume bootstrap role (OIDC)        │
│  └─ Deploy EKS stack (with full perms)  │
└─────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│  AWS: EKS Environment (environments/dev)│
│  ├─ VPC, subnets, security groups       │
│  ├─ EKS cluster & node group            │
│  ├─ GitHub Actions CI/CD role (full)    │
│  └─ RBAC policies & bindings            │
└─────────────────────────────────────────┘
```

## Security Design

### Trust Policy

The bootstrap role's trust policy is scoped to:

- **OIDC Provider**: `token.actions.githubusercontent.com`
- **Audience**: `sts.amazonaws.com` (GitHub's STS client ID)
- **Subject**: Exact GitHub repository + branch/environment

Example for `main` branch:
```
repo:victorbecerragit/secure-multi-cluster-oidc-k8s:ref:refs/heads/main
```

This ensures **only your repository on the main branch** can exchange GitHub's OIDC token for AWS credentials.

### Minimal Permissions

The bootstrap role has **no policies attached**. It is purely a trust boundary.

The actual permissions (EKS management, IAM, VPC, etc.) are granted to a separate role in the main stack, assumed by the workflow with additional scope constraints.

## Quick Start

### Prerequisites

- AWS CLI configured with credentials that have IAM permissions
- Terraform `>= 1.5`
- GitHub repository access to set repository secrets

### Step 1: Configure

```bash
cd infra/terraform/aws/bootstrap
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your GitHub repository details:

```hcl
github_owner         = "your-github-org-or-user"
github_repo          = "your-repo-name"
github_subject_type  = "branch"
github_subject_value = "main"
```

### Step 2: Apply Bootstrap

```bash
terraform init
terraform plan
terraform apply
```

### Step 3: Capture Output

After apply, Terraform outputs the role ARN:

```bash
terraform output github_oidc_role_arn
```

Example output:
```
"arn:aws:iam::123456789012:role/123456789012-github-actions-oidc-role"
```

### Step 4: Set GitHub Repository Secret

In your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Create a new repository secret:
   - **Name**: `AWS_GITHUB_OIDC_ROLE_ARN`
   - **Value**: Paste the ARN from step 3

This secret is now available to all workflows in the repository.

## Usage in Workflows

In your GitHub Actions workflow (e.g., `.github/workflows/deploy-eks.yml`):

```yaml
name: Deploy EKS Stack

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      
      - name: Assume AWS Role via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_GITHUB_OIDC_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: Deploy EKS Stack
        run: |
          cd infra/terraform/aws/environments/dev
          terraform init
          terraform plan
          terraform apply -auto-approve
```

## Troubleshooting

### "Token is not valid for this role"

The GitHub OIDC token subject doesn't match the trust policy. Verify:

1. **Repository name** matches `github_repo` variable
2. **Branch name** matches `github_subject_value` (if using `subject_type = "branch"`)
3. **Organization name** matches `github_owner` variable

Use the Terraform output to inspect the exact subject claim:

```bash
terraform output github_subject_claim
```

### "No valid provider found"

The GitHub OIDC provider was not created or the account ID is wrong. Verify:

```bash
aws iam list-open-id-connect-providers
```

Should list `token.actions.githubusercontent.com`. If not, re-run `terraform apply`.

### "OIDC provider already exists"

If the provider was created by another bootstrap stack, set `create_oidc_provider = false` in `main.tf` and pass the existing provider ARN. See the module documentation for details.

## Extending the Bootstrap

### For Multiple Environments

Create additional bootstrap stacks under `infra/terraform/aws/bootstrap-{env}/`:

```
bootstrap/
  └─ (main account, main branch)
bootstrap-staging/
  └─ (staging branch/environment)
bootstrap-prod/
  └─ (production environment)
```

Each has its own `terraform.tfvars` scoped to the appropriate branch/environment.

### For Multiple GitHub Organizations

Use module locals to loop and create roles for multiple organizations:

```hcl
variable "github_repositories" {
  type = map(object({
    owner = string
    repo  = string
  }))
}

module "github_oidc_roles" {
  for_each = var.github_repositories
  
  source = "../modules/github-oidc-role"
  # ... configured per repo
}
```

## Next Steps

1. **Apply this bootstrap stack locally** to create the OIDC provider and role
2. **Set the GitHub secret** with the output role ARN
3. **Deploy the main EKS stack** via workflow: `infra/terraform/aws/environments/dev/`
4. **Add RBAC bindings** in the EKS cluster for GitHub Actions user identity
5. **Implement namespace-scoped access** for additional security (see `docs/access-model.md`)

## References

- [AWS IAM OIDC Provider Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)
- [GitHub Actions: OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- Project documentation: `docs/aws-eks-github-oidc.md`
