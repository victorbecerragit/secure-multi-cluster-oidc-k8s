# Infrastructure as Code (Terraform)

This directory contains the Terraform modules for provisioning the Kubernetes clusters and configuring the OIDC provider.

## Modules

*   `environments/manager/`: Management cluster configuration.
*   `environments/workload/`: Workload federated cluster configuration.
*   `modules/eks/`: Reusable EKS cluster module.

## Usage

```bash
terraform init
terraform plan
```

> [!NOTE]
> These are skeleton modules. Actual implementation will follow in the next phase.
