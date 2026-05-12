# Infrastructure as Code (Terraform)

This directory contains the Terraform modules for provisioning the Kubernetes clusters and configuring the OIDC provider.

## Modules

*   `environments/manager/`: Management cluster configuration.
*   `environments/workload/`: Workload federated cluster configuration.
*   `modules/eks/`: Reusable EKS cluster module.
*   `aws/environments/dev/`: AWS dev environment for EKS + GitHub Actions OIDC.
*   `aws/modules/eks-cluster/`: AWS EKS cluster module wrapper.
*   `aws/modules/github-oidc-role/`: GitHub OIDC trust and IAM role module.

## Usage

```bash
terraform init
terraform plan
```

> [!NOTE]
> These are skeleton modules. Actual implementation will follow in the next phase.

## AWS Path

The AWS implementation lives under `infra/terraform/aws/` so the cloud path stays separate from the local kind + Keycloak lab.

Start with:

```bash
cd infra/terraform/aws/environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
```

For the trust model and CI/CD flow, see `docs/aws-eks-github-oidc.md`.
