# EKS Deployment Runbook (Zero-to-Hero)

This document provides a step-by-step guide to deploying the secure multi-cluster EKS environment from scratch on a new AWS account using the OIDC-first (Secretless) approach.

## Pre-requisites
- AWS Account ID configured in `infra/terraform/aws/environments/dev/terraform.tfvars`.
- Local AWS credentials with sufficient permissions to create IAM roles and OIDC providers.
- GitHub repository details (Owner/Repo) for the bootstrap configuration.

---

## Phase 1: Local Bootstrap
**Goal:** Establish OIDC trust between GitHub and AWS to enable secretless authentication.

1.  Navigate to `infra/terraform/aws/bootstrap/`.
2.  Create `terraform.tfvars` from `terraform.tfvars.example` and fill in your GitHub `owner` and `repo` name.
3.  Run the initial setup locally:
    ```bash
    terraform init
    terraform apply
    ```
4.  **Action:** Copy the `github_oidc_role_arn` from the terminal output.
5.  **GitHub Configuration:** Go to your GitHub repository -> Settings -> Secrets and Variables -> Actions -> Variables and create:
    - `AWS_GITHUB_OIDC_ROLE_ARN`: Value from the previous step.
    - `AWS_REGION`: Your preferred region (e.g., `us-east-1`).

---

## Phase 2: Infrastructure Deployment (Automated)
**Goal:** Provision the VPC, EKS Cluster, and specialized IAM roles for CI/CD via GitHub Actions.

1.  In GitHub, go to the **Actions** tab.
2.  Select the **Terraform AWS EKS Management** workflow.
3.  Click **Run workflow**.
4.  Select the `apply` action and click **Run workflow**.
5.  **Action:** Once finished, check the workflow logs for Terraform outputs and update your GitHub Variables:
    - `AWS_EKS_CLUSTER_NAME`: The name of the new cluster.
    - `AWS_GITHUB_DEPLOY_ROLE_ARN`: Standard deployer role.
    - `AWS_GITHUB_BUILD_ROLE_ARN`: Role for building/pushing images.
    - `AWS_GITHUB_DEPLOY_ROLE_PROD_ARN`: Production-specific deployment role.
    - `AWS_GITHUB_DEPLOY_ROLE_STAGING_ARN`: Staging-specific deployment role.

---

## Phase 3: Cluster Hardening & RBAC
**Goal:** Apply internal Kubernetes security policies, namespaces, and RBAC bindings.

1.  In GitHub, go to the **Actions** tab.
2.  Select the **EKS Deploy** workflow.
3.  Click **Run workflow** (or push changes to `deploy/eks/`).
4.  This will initialize the `app-prod` and `app-staging` namespaces with least-privilege permissions.

---

## Phase 4: Application Deployment
**Goal:** Build and deploy the sample application using the secure OIDC roles.

1.  Trigger the **CI/CD to EKS (OIDC)** workflow.
2.  This workflow will:
    - Assume the `BUILD` role to push to ECR.
    - Assume the `DEPLOY` role to install the Helm chart.
    - Deploy to the assigned namespace based on the branch.

---

## Validation Commands
After deployment, you can verify access using the `fcli` tool (if configured) or standard kubectl:

```bash
# Check who you are in the cluster
kubectl auth can-i "*" "*" --all-namespaces

# Verify namespace isolation
kubectl get pods -n app-prod
```

---

## Troubleshooting & Debugging

### EKS Access Entry Review
The cluster uses API-based Access Entries instead of the legacy `aws-auth` ConfigMap. Use these AWS CLI commands to verify who has access to the cluster:

```bash
# List all principals authorized via Access Entries
aws eks list-access-entries --cluster-name <cluster-name>

# View details for a specific principal (e.g., your local user)
aws eks describe-access-entry --cluster-name <cluster-name> --principal-arn <iam-arn>
```

### Local Connectivity
By default, newly created clusters may block your local IAM identity even if you created the cluster. Ensure your identity is mapped in the `access_entries` section of `infra/terraform/aws/environments/dev/main.tf`:

```hcl
# Example mapping for local connectivity
local_dev_user = {
  principal_arn     = "arn:aws:iam::<account-id>:user/<username>"
  kubernetes_groups = []
  policy_arn        = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope_type = "cluster"
}
```

Once applied, update your local kubeconfig:
```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```
