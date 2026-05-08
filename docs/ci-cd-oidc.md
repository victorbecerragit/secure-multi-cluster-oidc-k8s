# CI/CD: Secretless Authentication via GitHub Actions OIDC

This repository uses **OIDC (OpenID Connect)** to allow GitHub Actions workflows to communicate with Kubernetes clusters without the need for long-lived service account tokens or static kubeconfigs stored as GitHub Secrets.

## The OIDC Trust Flow

1.  **JWT Request**: The GitHub Actions runner requests a uniquely signed JWT from GitHub's OIDC provider.
2.  **Authentication**: The runner sends this JWT to the Kubernetes API server (or a cloud provider like AWS/GCP).
3.  **Verification**: Kubernetes verifies the JWT's signature against GitHub's public OIDC endpoint (`token.actions.githubusercontent.com`).
4.  **Authorization**: Kubernetes maps the `sub` (Subject) claim or group claims in the JWT to a Kubernetes identity (e.g., `oidc:ci-deployers`).
5.  **Access**: The job receives temporary access to perform actions permitted by the mapped RBAC roles.

## Security Best Practices

### 1. The `Subject` Claim (Least Privilege)
The OIDC trust relationship should always be restricted using the `sub` claim to ensure only specific repositories and branches can assume high-privilege roles.

**Example Subject Filter:**
`repo:victorbecerra/secure-multi-cluster-oidc-k8s:ref:refs/heads/main`

### 2. Permissions Block
Every workflow using OIDC must explicitly request the `id-token: write` permission:

```yaml
permissions:
  id-token: write # Required for requesting the JWT
  contents: read  # Required for actions/checkout
```

### 3. Short-lived Credentials
Tokens are valid only for the duration of the job, significantly reducing the blast radius if a runner is compromised.

## Provider-Specific Configuration

### AWS (EKS)
Use `aws-actions/configure-aws-credentials` to exchange the OIDC token for an IAM Role, which is then mapped to a K8s user via the `aws-auth` ConfigMap or EKS Access Entries.

### GCP (GKE)
Use `google-github-actions/auth` with Workload Identity Federation.

### Direct K8s OIDC
Configure the K8s API server flags:
*   `--oidc-issuer-url=https://token.actions.githubusercontent.com`
*   `--oidc-client-id=https://github.com/your-org`
