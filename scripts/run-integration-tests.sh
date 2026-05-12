#!/usr/bin/env bash
set -euo pipefail

# Default values for local kind environment
DEFAULT_ISSUER="https://host.docker.internal:30443/realms/kube-lab"
DEFAULT_CLIENT_ID="fcli"

# Use environment variables if set, otherwise use defaults
export FCLI_OIDC_ISSUER="${FCLI_OIDC_ISSUER:-$DEFAULT_ISSUER}"
export FCLI_OIDC_CLIENT_ID="${FCLI_OIDC_CLIENT_ID:-$DEFAULT_CLIENT_ID}"

echo "--- OIDC Integration Test Setup ---"
echo "Issuer:    $FCLI_OIDC_ISSUER"
echo "Client ID: $FCLI_OIDC_CLIENT_ID"
echo "-----------------------------------"

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT/tools/fcli"

echo "Running integration tests..."
go test -v -tags=integration ./...