# Local OIDC Validation Guide

## Overview
This guide walks you through end‑to‑end validation of the OIDC authentication flow for the two local `kind` clusters (`manager` and `workload`) that use Keycloak as the identity provider.

## Prerequisites
- `kind` clusters are up‑to‑date with the OIDC flags (see `kind/manager.yaml` / `workload.yaml`).
- Keycloak is running on the **manager** cluster and reachable at `http://keycloak.local:30000`.
- `kubelogin` (v0.0.28+), `kubectl`, `jq`, and `curl` are installed and in `$PATH`.
- The `/etc/hosts` file contains `127.0.0.1 keycloak.local`.

## Users & Groups
| User | Keycloak Group | Kubernetes Prefix |
|------|----------------|-------------------|
| `alice.admin` | `k8s-cluster-manager-platform-admin` | `oidc:k8s-cluster-manager-platform-admin` |
| `bob.viewer` | `k8s-cluster-workload-developer-readonly` | `oidc:k8s-cluster-workload-developer-readonly` |
| `ci.deployer` | `k8s-cluster-manager-ci-deployer` | `oidc:k8s-cluster-manager-ci-deployer` |

## Validation Scripts
Two scripts are provided in `scripts/`:
- `validate-oidc.sh` – positive test cases (allowed actions).
- `validate-oidc-negative.sh` – negative test cases (denied actions).

Both scripts use `kubelogin` to obtain an OIDC token for a given user, then run `kubectl auth can-i` with the `--as-user` and `--as-group` flags.

### Running the scripts
```bash
# Make them executable
chmod +x scripts/validate-oidc.sh scripts/validate-oidc-negative.sh

# Positive checks (should all succeed)
./scripts/validate-oidc.sh

# Negative checks (should be denied)
./scripts/validate-oidc-negative.sh
```

## Expected Output
The scripts print a brief table showing the command being executed and whether it succeeded (`yes`/`no`). Example of a successful check:
```
[alice.admin] can-i create deployments --as-user=oidc:alice.admin --as-group=oidc:k8s-cluster-manager-platform-admin (manager) → yes
```
A denial looks like:
```
[bob.viewer] can-i delete pods --as-user=oidc:bob.viewer --as-group=oidc:k8s-cluster-workload-developer-readonly (workload) → no (expected)
```

## Common Failure Points
1. **Missing `/etc/hosts` entry** – Keycloak discovery fails; the scripts will abort with `Issuer URL not reachable`.
2. **Keycloak not started** – Ensure `bootstrap-kind.sh` has run and the Keycloak pod is ready (`kubectl -n keycloak get pods`).
3. **`kubelogin` version** – Older versions do not support the `--oidc-issuer-url` flag. Upgrade if you see `unknown flag` errors.
4. **Incorrect group prefix** – The RBAC bindings must use the `oidc:` prefix; otherwise `kubectl auth can-i` will return `no` even for allowed actions.

## Cleaning Up
```bash
# Delete the Kind clusters (optional)
kind delete cluster --name manager
kind delete cluster --name workload
```
Re‑run `scripts/bootstrap-kind.sh` to start fresh.
