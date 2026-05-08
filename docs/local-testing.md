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

## Keycloak Access from Host

For local host access, use `kubectl port-forward` as the default validation path:

```bash
kubectl -n keycloak port-forward svc/keycloak 18080:80
```

Then open Keycloak on your host at `http://127.0.0.1:18080`.

Why this is the default:
- It is the fastest and most reliable local workflow.
- It avoids host DNS/route issues around `host.docker.internal`.
- It is reproducible across Linux/macOS/Windows local setups.

Why NodePort is still kept:
- The kind control-plane kube-apiserver uses the HTTPS issuer endpoint at `https://host.docker.internal:30443/realms/kube-lab`.
- That path depends on NodePort (`30443`) plus `extraPortMappings` in `kind/manager.yaml`.

## 🗑️ Teardown

To delete the clusters and clean up your environment:

```bash
bash scripts/destroy-kind.sh
```

## 📋 Note on Names

*   `kind-manager`: Management/Controller cluster.
*   `kind-workload`: Federated workload client cluster.
