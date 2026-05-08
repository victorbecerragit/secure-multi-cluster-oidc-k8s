#!/usr/bin/env bash
set -e

ISSUER="http://keycloak.local:30000/realms/kube-lab"
CLIENT="kubernetes"

# Helper to obtain token and run auth checks
run_check() {
  local USER=$1
  local GROUP=$2
  local CONTEXT=$3
  local ACTION=$4
  local RESOURCE=$5
  local NAMESPACE=$6

  echo "[${USER}] testing on ${CONTEXT}..."
  TOKEN=$(kubelogin token \
    --oidc-issuer-url "$ISSUER" \
    --client-id "$CLIENT" \
    --username "$USER" \
    --password "password123")
  # Decode payload for debugging (optional)
  # echo "$TOKEN" | cut -d '.' -f2 | base64 -d | jq .

  if kubectl auth can-i $ACTION $RESOURCE \
    --as=oidc:${USER} \
    --as-group=oidc:${GROUP} \
    ${NAMESPACE:+-n $NAMESPACE} \
    --context $CONTEXT; then
    echo "✅ ${USER} allowed $ACTION $RESOURCE on $CONTEXT"
  else
    echo "❌ ${USER} denied $ACTION $RESOURCE on $CONTEXT"
    exit 1
  fi
}

# Positive test cases
run_check "alice.admin" "k8s-cluster-manager-platform-admin" "kind-manager" "*" "*"
run_check "ci.deployer" "k8s-cluster-manager-ci-deployer" "kind-manager" "create" "deployments" "default"
run_check "bob.viewer" "k8s-cluster-workload-developer-readonly" "kind-workload" "get" "pods" "app-prod"

echo "All positive OIDC validation checks passed."
