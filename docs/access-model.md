# Access Model: OIDC to Kubernetes RBAC

This document outlines how external identities from the OIDC provider are mapped to internal Kubernetes permissions.

## Identity Mapping Logic

We use **Group-based access control**. The OIDC provider must include a `groups` claim in the ID token. Kubernetes is configured to prefix these groups with `oidc:` to avoid collisions with local system groups.

| OIDC Group | Kubernetes Persona | Role Mapping | Scope |
|------------|--------------------|--------------|-------|
| `platform-admins` | **Platform Admin** | `cluster-admin` | Cluster-wide |
| `developers` | **Developer** | `view` | Namespace-scoped (`app-prod`, `app-staging`) |
| `ci-deployers` | **CI/CD Service** | `edit` | Namespace-scoped (`app-prod`, `app-staging`) |
| `security-auditors` | **Security Auditor** | `view` | Cluster-wide |

## RBAC Strategy

1.  **Prefer Built-in Roles**: We utilize standard Kubernetes ClusterRoles (`view`, `edit`, `cluster-admin`) where possible. This reduces maintenance overhead and ensures compatibility with standard tools.
2.  **Namespace Isolation**: Developers and CI/CD services are strictly scoped to their respective application namespaces. They cannot view or modify system components in `kube-system` or other restricted namespaces.
3.  **Symmetric Configuration**: Both the **manager** and **workload** clusters follow the same RBAC patterns to ensure environment parity and reduce cognitive load for operators.

## Verification

Personas can be validated using the `scripts/check-auth.sh` tool, which simulates access for each group.
