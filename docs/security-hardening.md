# Security Hardening: Defense in Depth

This project implements a multi-layered security strategy to ensure that a compromise at one level does not lead to a total cluster breach.

## 🛡️ Security Layers

### 1. Identity & Access (OIDC + RBAC)
*   **OIDC Federation**: Strong identity verification via external provider.
*   **Least Privilege CI/CD**: The `github-ci-deployer` ClusterRole is strictly limited to application management. It **explicitly denies** access to `secrets` and `rbac.authorization.k8s.io` to prevent CI pipelines from leaking credentials or escalating their own permissions.
*   **Auditability**: A dedicated `security-auditor` role provides cluster-wide visibility without modification rights.

### 2. Workload Hardening (Pod Security Admission)
We use the native **Pod Security Admission (PSA)** controller to enforce security profiles at the namespace level (as seen in [`app-namespaces.yaml`](../examples/namespaces/app-namespaces.yaml)):
*   **`restricted` (Production)**: Enforces the highest security level. Pods must run as non-root, drop all dangerous capabilities, and cannot use host networking or host paths.
*   **`baseline` (Staging)**: Prevents known privilege escalations (e.g., `hostPath` is restricted) while allowing minimal flexibility for development.
*   **Audit & Warn**: All application namespaces are configured to `warn: restricted` to alert developers of upcoming security policy tightenings.

### 3. Network Segmentation (NetworkPolicies)
A **Zero-Trust Network** model is enforced via the `default-deny` core policy:
*   **Default Deny**: All traffic is blocked by default ([`default-deny.yaml`](../policies/network/default-deny.yaml)).
*   **Explicit Allows**: Only essential traffic is permitted ([`baseline-allow.yaml`](../policies/network/baseline-allow.yaml)):
    *   **Intra-namespace**: Pods within the same namespace can communicate freely.
    *   **CoreDNS**: Specific egress to `kube-system` on port 53 (UDP/TCP) is allowed to enable service discovery.

## 🚀 Hardening in Action

To verify the hardening, you can attempt to deploy a "privileged" pod to the `app-prod` namespace. The PSA controller will block the deployment because it violates the `restricted` profile.

```bash
# This will be rejected in app-prod
kubectl run root-shell --image=busybox -n app-prod --restart=Never -- /bin/sh
```
