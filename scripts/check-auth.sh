#!/bin/bash
# check-auth.sh: Validate RBAC permissions for OIDC personas

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function check_permission() {
    local user=$1
    local group=$2
    local namespace=$3
    local resource=$4
    local verb=$5

    echo -n "Checking if $group can $verb $resource in $namespace... "
    
    if kubectl auth can-i "$verb" "$resource" -n "$namespace" --as="test-user" --as-group="$group" >/dev/null 2>&1; then
        echo -e "${GREEN}YES${NC}"
    else
        echo -e "${RED}NO${NC}"
    fi
}

echo "=== RBAC Validation Suite ==="
echo

# 1. Platform Admin (Cluster-wide)
check_permission "admin" "oidc:platform-admins" "kube-system" "pods" "get"
check_permission "admin" "oidc:platform-admins" "default" "secrets" "create"

# 2. Developer (Read-only in app namespaces)
check_permission "dev" "oidc:developers" "app-prod" "pods" "get"
check_permission "dev" "oidc:developers" "app-prod" "pods" "delete" # Should be NO
check_permission "dev" "oidc:developers" "kube-system" "pods" "get" # Should be NO

# 3. CI/CD Deployer (Edit in app namespaces)
check_permission "ci" "oidc:ci-deployers" "app-prod" "deployments" "create"
check_permission "ci" "oidc:ci-deployers" "app-prod" "secrets" "get"
check_permission "ci" "oidc:ci-deployers" "default" "pods" "create" # Should be NO

# 4. Security Auditor (Cluster-wide Read-only)
check_permission "auditor" "oidc:security-auditors" "kube-system" "pods" "get"
check_permission "auditor" "oidc:security-auditors" "default" "secrets" "create" # Should be NO

echo
echo "Validation complete."
