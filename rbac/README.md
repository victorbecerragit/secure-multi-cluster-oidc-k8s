# Kubernetes RBAC

Manifests for ClusterRoles, Roles, and Bindings that enforce least-privilege access.

## Roles

*   `platform-admin`: Full access to the cluster.
*   `developer-readonly`: View-only access to specific namespaces.
*   `ci-deployer`: Permission to deploy workloads via GitHub Actions.

## Examples

See `roles/` and `bindings/` for YAML templates.
