# Authentication: EKS vs Local Kind

This document explains the technical differences between the local `kind` testing environment and the production-ready AWS EKS infrastructure.

## Comparison Table

| Feature | Local Kind | AWS EKS |
|---------|------------|---------|
| **OIDC Setup** | API Server flags (`--oidc-issuer-url`) | Managed OIDC Issuer URL per cluster |
| **Identity Provider** | Generic (Keycloak/GitHub) | AWS IAM + OIDC Federation |
| **Machine Auth** | ServiceAccount tokens | **IRSA** (IAM Roles for Service Accounts) |
| **User Mapping** | RBAC ClusterRoleBindings | **EKS Access Entry API** / `aws-auth` ConfigMap |
| **Secret Storage** | Kubernetes Secrets (Base64) | AWS Secrets Manager / KMS Integration |

## Key Concepts

### 1. IRSA (IAM Roles for Service Accounts)
In EKS, we don't just use Kubernetes RBAC. We associate a Kubernetes ServiceAccount with an AWS IAM Role. This allows pods to call AWS APIs (like S3 or DynamoDB) using temporary credentials, following the principle of least privilege.

### 2. EKS Access Entries
The new EKS Access Entry API (used in our Terraform modules) is the modern replacement for the `aws-auth` ConfigMap. It allows managing Kubernetes RBAC permissions directly via the AWS API, making the bootstrap process more robust and easier to automate via Terraform.

### 3. GitHub Actions OIDC
While `kind` requires a reachable OIDC endpoint, EKS integrates with GitHub Actions via **IAM OIDC Identity Providers**. The GitHub JWT is exchanged for an IAM Role, which is then mapped into the cluster via an Access Entry.

## Transitioning from Kind to EKS

1.  **Validate Locally**: Use `scripts/bootstrap-kind.sh` to ensure your RBAC and NetworkPolicies are correct.
2.  **Provision Infra**: Use `infra/terraform/` to spin up the EKS clusters.
3.  **Map Personas**: Update the EKS Access Entries to map your IAM users/roles to the `oidc:platform-admins` or `oidc:developers` groups defined in the manifests.
