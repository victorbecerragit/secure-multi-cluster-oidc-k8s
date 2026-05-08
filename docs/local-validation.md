# Local OIDC Validation Guide

## Overview
This guide walks you through end‑to‑end validation of the OIDC authentication flow for the two local `kind` clusters (`manager` and `workload`) that use Keycloak as the identity provider.

## Prerequisites
- `kind` clusters are up‑to‑date with the OIDC flags (see `kind/manager.yaml` / `workload.yaml`).
- Keycloak is running on the **manager** cluster.
- OIDC issuer is reachable at `https://host.docker.internal:30443/realms/kube-lab`.
- Local OIDC CA is present at `certs/oidc-ca.crt`.
- `kubelogin` (v0.0.28+), `kubectl`, `jq`, and `curl` are installed and in `$PATH`.
- Docker host mapping for `host.docker.internal` is working (validated by `scripts/bootstrap-kind.sh`).

## Users & Groups
| User | Keycloak Group | Kubernetes Prefix |
|------|----------------|-------------------|
| `alice.admin` | `platform-admins` | `oidc:platform-admins` |
| `bob.viewer` | `developers` | `oidc:developers` |
| `ci.deployer` | `ci-deployers` | `oidc:ci-deployers` |

## Validation Scripts
Two scripts are provided in `scripts/`:
- `validate-oidc.sh` – positive test cases (allowed actions).
- `validate-oidc-negative.sh` – negative test cases (denied actions).

Both scripts validate using real OIDC bearer tokens from Keycloak (`kubelogin` first, `curl` fallback), then run `kubectl auth can-i` with `--token`.

For troubleshooting only, you can allow impersonation fallback:

```bash
ALLOW_IMPERSONATION_FALLBACK=true ./scripts/validate-oidc.sh
```

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
Example of a successful check:
```
[alice.admin] testing on kind-manager...
✅ alice.admin allowed get nodes on kind-manager
```
A denial looks like:
```
[bob.viewer] testing on kind-workload...
❌ bob.viewer denied delete pods on kind-workload
```

## Common Failure Points
1. **Missing local certs** – Run `bash scripts/ensure-oidc-certs.sh` before creating clusters.
2. **Keycloak not started** – Ensure `bootstrap-kind.sh` has run and the Keycloak pod is ready (`kubectl -n keycloak get pods`).
3. **`kubelogin` version** – Older versions do not support the `--oidc-issuer-url` flag. Upgrade if you see `unknown flag` errors.
4. **Incorrect group mapping** – The RBAC bindings use `oidc:platform-admins`, `oidc:ci-deployers`, and `oidc:developers`.

## Cleaning Up
```bash
# Delete the Kind clusters (optional)
kind delete cluster --name manager
kind delete cluster --name workload
```
Re‑run `scripts/bootstrap-kind.sh` to start fresh.
