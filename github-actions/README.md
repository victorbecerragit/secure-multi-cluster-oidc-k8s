# GitHub Actions OIDC Templates

This directory contains documentation and templates for secretless CI/CD.

## Live Workflows

The active workflows are located in the [`.github/workflows/`](../.github/workflows/) directory:

*   [`deploy-manager.yml`](../.github/workflows/deploy-manager.yml): Deployment persona for production.
*   [`validate-workload.yml`](../.github/workflows/validate-workload.yml): Read-only validation persona.

## Documentation

For a deep dive into how OIDC trust is established, see [**docs/ci-cd-oidc.md**](../docs/ci-cd-oidc.md).
