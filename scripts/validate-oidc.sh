#!/usr/bin/env bash
set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
ISSUER="https://host.docker.internal:30443/realms/kube-lab"
ISSUER_HOST="host.docker.internal"
ISSUER_PORT="30443"
KEYCLOAK_BASE_URL="https://$ISSUER_HOST:$ISSUER_PORT"
KEYCLOAK_ADMIN_USER="${KEYCLOAK_ADMIN_USER:-admin}"
KEYCLOAK_ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD:-admin-password}"
CLIENT="kubernetes"
CA_CERT="$REPO_ROOT/certs/oidc-ca.crt"
DEFAULT_PASSWORD="password123"
ALLOW_IMPERSONATION_FALLBACK="${ALLOW_IMPERSONATION_FALLBACK:-false}"

CA_FLAG=()
if command -v kubelogin >/dev/null 2>&1 && kubelogin token --help 2>&1 | grep -q -- '--certificate-authority'; then
  CA_FLAG=(--certificate-authority "$CA_CERT")
fi

require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: Required command '$cmd' is not installed or not in PATH."
    exit 1
  fi
}

require_cmd kubectl
require_cmd curl

get_token_with_kubelogin() {
  local user=$1
  kubelogin token \
    --oidc-issuer-url "$ISSUER" \
    "${CA_FLAG[@]}" \
    --client-id "$CLIENT" \
    --username "$user" \
    --password "$DEFAULT_PASSWORD"
}

get_token_with_keycloak() {
  local user=$1
  require_cmd jq

  local token_endpoint="$ISSUER/protocol/openid-connect/token"
  local curl_args=(
    -sS --fail
    --connect-timeout 10
    --max-time 30
    --cacert "$CA_CERT"
    --resolve "$ISSUER_HOST:$ISSUER_PORT:127.0.0.1"
    -X POST "$token_endpoint"
    -H "Content-Type: application/x-www-form-urlencoded"
    --data-urlencode "grant_type=password"
    --data-urlencode "client_id=$CLIENT"
    --data-urlencode "username=$user"
    --data-urlencode "password=$DEFAULT_PASSWORD"
  )

  local response
  local token

  if ! response=$(curl "${curl_args[@]}" 2>/tmp/validate-oidc-curl.err); then
    cat /tmp/validate-oidc-curl.err >&2 || true
    return 1
  fi

  token=$(echo "$response" | jq -r '.access_token // empty')
  if [ -z "$token" ]; then
    echo "ERROR: Keycloak token response did not include access_token for user '$user'." >&2
    echo "Response: $response" >&2
    return 1
  fi

  echo "$token"
}

get_oidc_token() {
  local user=$1

  if command -v kubelogin >/dev/null 2>&1; then
    if get_token_with_kubelogin "$user"; then
      return
    fi
    echo "WARN: kubelogin failed for $user, trying direct Keycloak token request." >&2
  fi

  echo "INFO: Using direct Keycloak token request via curl." >&2
  get_token_with_keycloak "$user"
}

# Helper to obtain token and run auth checks
run_check() {
  local USER=$1
  local GROUP=$2
  local CONTEXT=$3
  local ACTION=$4
  local RESOURCE=$5
  local NAMESPACE=$6
  local EXPECTED_PASS=${7:-true}

  echo "[${USER}] testing on ${CONTEXT}..."
  TOKEN=$(get_oidc_token "$USER")

  local ACTUAL_PASS=false

  if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    if [ "$ALLOW_IMPERSONATION_FALLBACK" = "true" ]; then
      echo "WARN: Failed to obtain OIDC token for user '$USER'. Falling back to impersonation-based RBAC check." >&2
      if kubectl auth can-i "$ACTION" "$RESOURCE" \
        --as "oidc:${USER}" \
        --as-group "oidc:${GROUP}" \
        ${NAMESPACE:+-n $NAMESPACE} \
        --context "$CONTEXT" >/dev/null 2>&1; then
        ACTUAL_PASS=true
      fi
    else
      echo "ERROR: Failed to obtain OIDC token for user '$USER' and strict mode is enabled." >&2
      echo "Hint: run scripts/setup-keycloak.sh or set ALLOW_IMPERSONATION_FALLBACK=true." >&2
      exit 1
    fi
  else
    if kubectl --token "$TOKEN" auth can-i "$ACTION" "$RESOURCE" \
      ${NAMESPACE:+-n $NAMESPACE} \
      --context "$CONTEXT" >/dev/null 2>&1; then
      ACTUAL_PASS=true
    fi
  fi

  if [ "$ACTUAL_PASS" = "$EXPECTED_PASS" ]; then
    local STATUS="✅"
    [ "$EXPECTED_PASS" = "false" ] && STATUS="🚫"
    echo "$STATUS ${USER} $([ "$EXPECTED_PASS" = "true" ] && echo "allowed" || echo "correctly denied") $ACTION $RESOURCE on $CONTEXT"
  else
    echo "❌ ${USER} expected $([ "$EXPECTED_PASS" = "true" ] && echo "allow" || echo "deny") but got $([ "$ACTUAL_PASS" = "true" ] && echo "allow" || echo "deny") for $ACTION $RESOURCE on $CONTEXT"
    exit 1
  fi
}

# Positive test cases
run_check "alice.admin" "platform-admins" "kind-manager" "get" "nodes" "" "true"
run_check "ci.deployer" "ci-deployers" "kind-manager" "create" "deployments" "app-prod" "true"
run_check "bob.viewer" "developers" "kind-workload" "get" "pods" "app-staging" "true"
run_check "charlie.auditor" "security-auditors" "kind-manager" "get" "nodes" "" "true"

# Negative test cases (Denial checks)
echo "--- Running Denial Checks ---"
run_check "bob.viewer" "developers" "kind-manager" "delete" "nodes" "" "false"
run_check "ci.deployer" "ci-deployers" "kind-manager" "delete" "namespace" "kube-system" "false"
run_check "charlie.auditor" "security-auditors" "kind-workload" "create" "pods" "app-prod" "false"

echo "All OIDC validation checks (positive and negative) passed."
