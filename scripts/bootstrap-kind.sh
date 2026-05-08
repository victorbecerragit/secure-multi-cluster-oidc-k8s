#!/bin/bash
# bootstrap-kind.sh: Create and configure two local kind clusters

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

bash "$REPO_ROOT/scripts/ensure-oidc-certs.sh"

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

# Ensure prerequisites are installed
for cmd in kind helm jq curl openssl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Verify Docker host hostname mapping for Keycloak
if ! ping -c1 -W1 host.docker.internal > /dev/null 2>&1; then
    echo "WARNING: 'host.docker.internal' not reachable from this environment."
    echo "If you are using Docker on Linux, ensure you run the Docker daemon with '--add-host=host.docker.internal:host-gateway' or use the 'host-gateway' feature."
    echo "Alternatively, add an entry to /etc/hosts mapping host.docker.internal to your Docker host IP."
    read -p "Press Enter to continue after fixing host mapping, or Ctrl+C to abort..."
fi

create_cluster "manager" "$REPO_ROOT/kind/manager.yaml"

# Setup Keycloak on manager cluster before OIDC reachability checks
bash "$REPO_ROOT/scripts/setup-keycloak.sh"

    # Verify OIDC issuer reachability from manager control-plane.
    # NodePort 30443 is bound on the kind node itself, not on the Docker host.
    # From inside the container, use --resolve to map host.docker.internal:30443
    # to 127.0.0.1 so curl hits the local NodePort while still using the correct
    # SNI/hostname for TLS certificate verification against the mounted CA.
    echo "Checking OIDC issuer reachability from control-plane..."
    docker exec manager-control-plane curl -s \
        --cacert /etc/kubernetes/pki/oidc/ca.crt \
        --resolve host.docker.internal:30443:127.0.0.1 \
        -o /dev/null -w "%{http_code}" \
        https://host.docker.internal:30443/realms/kube-lab || {
      echo "ERROR: Cannot reach OIDC issuer from kind control-plane."
      exit 1
    }


create_cluster "workload" "$REPO_ROOT/kind/workload.yaml"

echo
echo "Bootstrap complete."
echo "Keycloak HTTP (admin): http://host.docker.internal:30000"
echo "OIDC Issuer HTTPS: https://host.docker.internal:30443/realms/kube-lab"
echo "Contexts: kind-manager, kind-workload"
echo
echo "To test OIDC login, refer to docs/local-validation.md"
