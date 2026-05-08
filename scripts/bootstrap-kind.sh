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

# Ensure kind is installed
if ! command -v kind &> /dev/null; then
    echo "Error: kind is not installed. Please install it first."
    exit 1
fi

create_cluster "manager" "$REPO_ROOT/kind/manager.yaml"
create_cluster "workload" "$REPO_ROOT/kind/workload.yaml"

echo
echo "Bootstrap complete."
echo "Contexts: kind-manager, kind-workload"
