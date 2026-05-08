# Local Testing with Kind

This repository provides a fully automated local testing environment using **Kind** (Kubernetes in Docker). This allows you to validate the multi-cluster RBAC, NetworkPolicies, and Pod Security configurations on your local machine.

## Prerequisites

*   **Docker**: Ensure Docker is installed and running.
*   **Kind**: [Installation Guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
*   **Kubectl**: Standard Kubernetes CLI.

## 🚀 Bootstrap the Environment

The bootstrap script creates two clusters (`manager`, `workload`) and applies all security manifests.

```bash
bash scripts/bootstrap-kind.sh
```

This will:
1.  Create the clusters using the configs in `kind/`.
2.  Set up the `kubeconfig` contexts.
3.  Apply namespaces, RBAC bindings, and NetworkPolicies.

## ✅ Run Validations

Validate that the security model is correctly enforced across both clusters.

```bash
bash scripts/validate-local.sh
```

The validation suite checks:
*   **RBAC Personas**: Simulates Admin, Developer, CI, and Auditor access.
*   **PSA Enforcement**: Verifies Pod Security Admission labels on namespaces.
*   **Network Segmentation**: Verifies the presence of functional NetworkPolicies.

## 🗑️ Teardown

To delete the clusters and clean up your environment:

```bash
bash scripts/destroy-kind.sh
```

## 📋 Note on Names

*   `kind-manager`: Management/Controller cluster.
*   `kind-workload`: Federated workload client cluster.
