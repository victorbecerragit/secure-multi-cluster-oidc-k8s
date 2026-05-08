# Security Hardening: Defense in Depth

This project implements a multi-layered security strategy to ensure that a compromise at one level does not lead to a total cluster breach.

## 🛡️ Security Layers

### 1. Identity & Access (OIDC + RBAC)
*   **OIDC Federation**: Strong identity verification via external provider.
*   **Least Privilege**: Personas are strictly scoped (e.g., `developer-readonly` can only view application namespaces).
*   **Auditability**: A dedicated `security-auditor` role provides cluster-wide visibility without modification rights.

### 2. Workload Hardening (Pod Security Admission)
We use the native **Pod Security Admission (PSA)** controller to enforce security profiles at the namespace level:
*   **`restricted` (Production)**: Enforces the highest security level, requiring pods to run as non-root and dropping all dangerous capabilities.
*   **`baseline` (Staging)**: Prevents known privilege escalations while allowing more flexibility for development.

### 3. Network Segmentation (NetworkPolicies)
A **Zero-Trust Network** model is enforced:
*   **Default Deny**: All traffic is blocked by default ([`default-deny.yaml`](../policies/network/default-deny.yaml)).
*   **Explicit Allows**: Only essential traffic is permitted, such as DNS resolution to `kube-system` and intra-namespace communication ([`baseline-allow.yaml`](../policies/network/baseline-allow.yaml)).

## 🚀 Hardening in Action

To verify the hardening, you can attempt to deploy a "privileged" pod to the `app-prod` namespace. The PSA controller will block the deployment because it violates the `restricted` profile.

```bash
# This will be rejected in app-prod
kubectl run root-shell --image=busybox -n app-prod --restart=Never -- /bin/sh
```
