#!/bin/bash
# setup-keycloak.sh: Deploy and configure Keycloak for K8s OIDC

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
CONTEXT="kind-manager"
NAMESPACE="keycloak"
KEYCLOAK_ADMIN_URL="http://127.0.0.1:18080"
KEYCLOAK_ISSUER_URL="https://host.docker.internal:30443"
PORT_FORWARD_PID=""
CA_CERT="$REPO_ROOT/certs/oidc-ca.crt"
SERVER_CERT="$REPO_ROOT/certs/oidc-server.crt"
SERVER_KEY="$REPO_ROOT/certs/oidc-server.key"

cleanup() {
  if [ -n "$PORT_FORWARD_PID" ] && kill -0 "$PORT_FORWARD_PID" >/dev/null 2>&1; then
    kill "$PORT_FORWARD_PID" >/dev/null 2>&1 || true
    wait "$PORT_FORWARD_PID" 2>/dev/null || true
  fi
}

start_port_forward() {
  kubectl -n "$NAMESPACE" port-forward svc/keycloak 18080:80 >/tmp/keycloak-port-forward.log 2>&1 &
  PORT_FORWARD_PID=$!

  for _ in $(seq 1 30); do
    if ! kill -0 "$PORT_FORWARD_PID" >/dev/null 2>&1; then
      echo "Error: kubectl port-forward terminated early."
      cat /tmp/keycloak-port-forward.log || true
      exit 1
    fi

    if curl -fsS "$KEYCLOAK_ADMIN_URL/realms/master/.well-known/openid-configuration" >/dev/null 2>&1; then
      return
    fi

    sleep 1
  done

  echo "Error: timed out waiting for local Keycloak port-forward readiness."
  cat /tmp/keycloak-port-forward.log || true
  exit 1
}

trap cleanup EXIT

bash "$REPO_ROOT/scripts/ensure-oidc-certs.sh"

if [ ! -f "$CA_CERT" ] || [ ! -f "$SERVER_CERT" ] || [ ! -f "$SERVER_KEY" ]; then
  echo "Error: missing generated OIDC TLS files in $REPO_ROOT/certs"
  exit 1
fi

echo "=== Deploying Keycloak to $CONTEXT ==="
kubectl config use-context "$CONTEXT"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install keycloak bitnami/keycloak \
  --namespace "$NAMESPACE" \
  --values "$REPO_ROOT/helm/values/keycloak-values.yaml" \
  --wait

kubectl -n "$NAMESPACE" create secret tls keycloak-https-tls \
  --cert "$SERVER_CERT" \
  --key "$SERVER_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$REPO_ROOT/examples/keycloak/https-proxy.yaml"
kubectl -n "$NAMESPACE" rollout status deploy/keycloak-https-proxy --timeout=180s

echo "=== Starting local Keycloak access via kubectl port-forward ==="
start_port_forward

echo "=== Waiting for Keycloak admin API to be reachable at $KEYCLOAK_ADMIN_URL ==="
until curl -fsS "$KEYCLOAK_ADMIN_URL/realms/master/.well-known/openid-configuration" > /dev/null; do
  echo "Keycloak is not ready yet..."
  sleep 5
done

echo "=== Configuring Keycloak Realm and Client ==="

# Get Admin Token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_ADMIN_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin-password" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

kc_get() {
  local path=$1
  curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_ADMIN_URL$path"
}

kc_post() {
  local path=$1
  local payload=$2
  curl -s -X POST "$KEYCLOAK_ADMIN_URL$path" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null
}

kc_put() {
  local path=$1
  local payload=$2
  curl -s -X PUT "$KEYCLOAK_ADMIN_URL$path" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null
}

ensure_realm() {
  local realm_id
  realm_id=$(kc_get "/admin/realms" | jq -r '.[] | select(.realm=="kube-lab") | .realm' | head -n1)

  if [ -z "$realm_id" ]; then
    echo "Creating realm kube-lab..."
    kc_post "/admin/realms" '{
      "realm": "kube-lab",
      "enabled": true,
      "displayName": "Kubernetes OIDC Lab"
    }'
  else
    echo "Realm kube-lab already exists."
  fi
}

ensure_client() {
  local client_id
  client_id=$(kc_get "/admin/realms/kube-lab/clients?clientId=kubernetes" | jq -r '.[0].id')

  if [ -z "$client_id" ] || [ "$client_id" = "null" ]; then
    echo "Creating client kubernetes..." >&2
    kc_post "/admin/realms/kube-lab/clients" '{
      "clientId": "kubernetes",
      "enabled": true,
      "publicClient": true,
      "directAccessGrantsEnabled": true,
      "redirectUris": ["http://localhost:8000", "http://localhost:18000"],
      "attributes": {
        "oauth2.device.authorization.grant.enabled": "true",
        "post.logout.redirect.uris": "+"
      }
    }'
    client_id=$(kc_get "/admin/realms/kube-lab/clients?clientId=kubernetes" | jq -r '.[0].id')
  else
    echo "Client kubernetes already exists. Ensuring direct grants are enabled..." >&2
    kc_put "/admin/realms/kube-lab/clients/$client_id" '{
      "clientId": "kubernetes",
      "enabled": true,
      "publicClient": true,
      "directAccessGrantsEnabled": true,
      "standardFlowEnabled": true,
      "redirectUris": ["http://localhost:8000", "http://localhost:18000"],
      "attributes": {
        "oauth2.device.authorization.grant.enabled": "true",
        "post.logout.redirect.uris": "+"
      }
    }'
  fi

  echo "$client_id"
}

ensure_groups_mapper() {
  local client_id=$1
  local mapper_id
  mapper_id=$(kc_get "/admin/realms/kube-lab/clients/$client_id/protocol-mappers/models" | jq -r '.[] | select(.name=="groups") | .id' | head -n1)

  if [ -z "$mapper_id" ]; then
    echo "Creating groups protocol mapper..."
    kc_post "/admin/realms/kube-lab/clients/$client_id/protocol-mappers/models" '{
      "name": "groups",
      "protocol": "openid-connect",
      "protocolMapper": "oidc-group-membership-mapper",
      "config": {
        "full.path": "false",
        "id.token.claim": "true",
        "access.token.claim": "true",
        "claim.name": "groups",
        "userinfo.token.claim": "true"
      }
    }'
  else
    echo "Groups protocol mapper already exists."
  fi
}

ensure_group() {
  local group=$1
  local group_id
  group_id=$(kc_get "/admin/realms/kube-lab/groups?search=$group" | jq -r '.[] | select(.name=="'"$group"'") | .id' | head -n1)

  if [ -z "$group_id" ]; then
    echo "Creating group $group..."
    kc_post "/admin/realms/kube-lab/groups" "{\"name\":\"$group\"}"
  fi
}

upsert_user() {
  local username=$1
  local password=$2
  local group=$3
  local first_name=$4
  local last_name=$5
  local user_id
  local group_id

  user_id=$(kc_get "/admin/realms/kube-lab/users?username=$username" | jq -r '.[0].id')

  if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
    echo "Creating user $username..."
    kc_post "/admin/realms/kube-lab/users" "{
      \"username\": \"$username\",
      \"enabled\": true,
      \"email\": \"$username@example.com\",
      \"emailVerified\": true,
      \"firstName\": \"$first_name\",
      \"lastName\": \"$last_name\",
      \"requiredActions\": [],
      \"credentials\": [{\"type\": \"password\", \"value\": \"$password\", \"temporary\": false}]
    }"
    user_id=$(kc_get "/admin/realms/kube-lab/users?username=$username" | jq -r '.[0].id')
  else
    echo "Updating user $username..."
    kc_put "/admin/realms/kube-lab/users/$user_id" "{
      \"id\": \"$user_id\",
      \"username\": \"$username\",
      \"enabled\": true,
      \"email\": \"$username@example.com\",
      \"emailVerified\": true,
      \"firstName\": \"$first_name\",
      \"lastName\": \"$last_name\",
      \"requiredActions\": []
    }"

    kc_put "/admin/realms/kube-lab/users/$user_id/reset-password" "{
      \"type\": \"password\",
      \"value\": \"$password\",
      \"temporary\": false
    }"
  fi

  group_id=$(kc_get "/admin/realms/kube-lab/groups?search=$group" | jq -r '.[] | select(.name=="'"$group"'") | .id' | head -n1)
  if [ -n "$group_id" ] && [ "$group_id" != "null" ]; then
    curl -s -X PUT "$KEYCLOAK_ADMIN_URL/admin/realms/kube-lab/users/$user_id/groups/$group_id" \
      -H "Authorization: Bearer $ADMIN_TOKEN" >/dev/null
  fi
}

ensure_realm
CLIENT_ID=$(ensure_client)
ensure_groups_mapper "$CLIENT_ID"

# Groups aligned with RBAC bindings (oidc:<group>)
ensure_group "platform-admins"
ensure_group "ci-deployers"
ensure_group "developers"
ensure_group "security-auditors"

upsert_user "alice.admin" "password123" "platform-admins" "Alice" "Admin"
upsert_user "bob.viewer" "password123" "developers" "Bob" "Viewer"
upsert_user "charlie.auditor" "password123" "security-auditors" "Charlie" "Auditor"
upsert_user "ci.deployer" "password123" "ci-deployers" "CI" "Deployer"

echo "=== Keycloak Setup Complete ==="
echo "Local admin URL (via port-forward): $KEYCLOAK_ADMIN_URL"
echo "Issuer URL: $KEYCLOAK_ISSUER_URL/realms/kube-lab"
