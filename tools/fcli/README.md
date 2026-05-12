# fcli: Secure Multi-Cluster K8s CLI

A minimal CLI for secure, user-friendly access to multiple Kubernetes clusters using OIDC (Keycloak) and RBAC.

## Commands
- `login`      Authenticate via OIDC (Keycloak)
- `clusters`   List available clusters (requires login)
- `switch`     Switch current context to a cluster (requires login)
- `whoami`     Show current identity/context (requires login)
- `validate`   Validate access to a cluster (requires login)

## Design
- No static secrets; OIDC only
- Minimal dependencies (Cobra, OIDC, YAML)
- Extensible, clean, and interview-ready


## Getting Started
```sh
cd tools/fcli
# Build
go build
# Run
./fcli --help
```

### OIDC Login (Keycloak)

Set the following environment variables before running `fcli login`:

- `FCLI_OIDC_ISSUER`   (e.g. https://keycloak.example.com/realms/myrealm)
- `FCLI_OIDC_CLIENT_ID` (e.g. fcli)

The login command will attempt OIDC device code flow. If not implemented, see below for manual login instructions.

#### Manual Device Code Flow (if not implemented)

1. Open your browser and visit the device code URL provided by your Keycloak instance.
2. Enter the user code and complete authentication.
3. Paste the resulting access token into the cache file (see below) or wait for CLI support.


### Cluster Discovery & Context Switching

The `clusters` command lists all clusters found in your kubeconfig. The `switch` command sets the current context to the specified cluster (by name). Both require a valid OIDC login and a readable kubeconfig file (usually at `${HOME}/.kube/config`).

Example:

```sh
./fcli clusters
# Output:
# Available clusters:
# - manager
# - workload

./fcli switch workload
# Output:
# Switched context to 'workload'
```

### Token Caching

Tokens are cached at `${HOME}/.fcli/token.json` (permissions 0600). This file is used for all authenticated commands.

## Project Structure
- `cmd/`      CLI commands
- `internal/oidc/` OIDC login logic
- `internal/cache/` Token caching utilities
- `internal/kube/` Kubeconfig and RBAC logic
- `test/`     Integration tests

---

**Phase 3 Status:**
- OIDC login and token caching are implemented. Device code flow is supported.
- Cluster discovery (`clusters`) and context switching (`switch`) are implemented and documented.
- All commands check for a cached token and print a helpful message if not logged in.
