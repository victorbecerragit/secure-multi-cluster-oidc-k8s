#!/bin/bash
# bootstrap-kind.sh: Create and configure two local kind clusters

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)

function create_cluster() {
    local name=$1
    local config=$2
    local context="kind-$name"

    echo "=== Creating cluster: $name ==="
    if kind get clusters | grep -q "^$name$"; then
        echo "Cluster $name already exists. Skipping creation."
    else
        kind create cluster --name "$name" --config "$config"
    fi

    echo "=== Applying manifests to $name ==="
    kubectl config use-context "$context"

    # 1. Namespaces
    kubectl apply -f "$REPO_ROOT/examples/namespaces/app-namespaces.yaml"

    # 2. RBAC
    kubectl apply -f "$REPO_ROOT/rbac/$name/bindings/"

    # 3. NetworkPolicies
    kubectl apply -f "$REPO_ROOT/policies/network/"
}

# Ensure kind and helm are installed
for cmd in kind helm jq curl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Check for keycloak.local in /etc/hosts
if ! grep -q "keycloak.local" /etc/hosts; then
    echo "WARNING: 'keycloak.local' not found in /etc/hosts."
    echo "Please add the following line to your /etc/hosts file:"
    echo "127.0.0.1 keycloak.local"
    echo
    read -p "Press Enter to continue after adding it, or Ctrl+C to abort..."
fi

create_cluster "manager" "$REPO_ROOT/kind/manager.yaml"

# Setup Keycloak on manager cluster
bash "$REPO_ROOT/scripts/setup-keycloak.sh"

create_cluster "workload" "$REPO_ROOT/kind/workload.yaml"

echo
echo "Bootstrap complete."
echo "Keycloak: http://keycloak.local:30000"
echo "Contexts: kind-manager, kind-workload"
echo
echo "To test OIDC login, refer to docs/local-testing-oidc.md"
