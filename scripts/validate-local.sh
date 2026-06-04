#!/bin/bash
# validate-local.sh: Validate security model across all local clusters

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)

function validate_cluster() {
    local context=$1
    echo "===================================================="
    echo " Validating Context: $context"
    echo "===================================================="
    
    kubectl config use-context "$context"
    
    # 1. Run RBAC persona validation
    bash "$REPO_ROOT/scripts/check-auth.sh"
    
    # 2. Basic PSA verification (Check for labels on namespaces)
    echo -n "Verifying PSA labels on app-prod... "
    if kubectl get ns app-prod -L pod-security.kubernetes.io/enforce | grep -q "restricted"; then
        echo "OK"
    else
        echo "FAILED"
    fi

    # 3. Basic NetPol verification
    echo -n "Verifying NetworkPolicies in app-prod... "
    if kubectl get netpol -n app-prod | grep -q "baseline-allow"; then
        echo "OK"
    else
        echo "FAILED"
    fi
    echo
}

validate_cluster "kind-manager"
validate_cluster "kind-workload"

echo "All local validations complete."
