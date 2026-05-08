#!/bin/bash
# setup-keycloak.sh: Deploy and configure Keycloak for K8s OIDC

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
CONTEXT="kind-manager"
NAMESPACE="keycloak"
KEYCLOAK_URL="http://keycloak.local:30000"

echo "=== Deploying Keycloak to $CONTEXT ==="
kubectl config use-context "$CONTEXT"
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install keycloak bitnami/keycloak \
  --namespace "$NAMESPACE" \
  --values "$REPO_ROOT/helm/values/keycloak-values.yaml" \
  --wait

echo "=== Waiting for Keycloak to be reachable at $KEYCLOAK_URL ==="
until curl -s "$KEYCLOAK_URL/health/live" > /dev/null; do
  echo "Keycloak is not ready yet... (Check if keycloak.local is in /etc/hosts)"
  sleep 5
done

echo "=== Configuring Keycloak Realm and Client ==="

# Get Admin Token
ADMIN_TOKEN=$(curl -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=admin" \
  -d "password=admin-password" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

# Create Realm kube-lab
curl -s -X POST "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "kube-lab",
    "enabled": true,
    "displayName": "Kubernetes OIDC Lab"
  }'

# Create Client kubernetes
curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "kubernetes",
    "enabled": true,
    "publicClient": true,
    "directAccessGrantsEnabled": true,
    "redirectUris": ["http://localhost:8000", "http://localhost:18000"],
    "attributes": {
      "post.logout.redirect.uris": "+"
    }
  }'

# Add Protocol Mapper for Groups
CLIENT_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/kube-lab/clients?clientId=kubernetes" | jq -r '.[0].id')

curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/clients/$CLIENT_ID/protocol-mappers/models" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
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

# Create Groups
curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/groups" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"name": "k8s-cluster-manager-platform-admin"}'
curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/groups" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"name": "k8s-cluster-manager-ci-deployer"}'
curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/groups" -H "Authorization: Bearer $ADMIN_TOKEN" -H "Content-Type: application/json" -d '{"name": "k8s-cluster-workload-developer-readonly"}'

# Create Users
function create_user() {
  local username=$1
  local password=$2
  local group=$3

  echo "Creating user $username..."
  curl -s -X POST "$KEYCLOAK_URL/admin/realms/kube-lab/users" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"$username\",
      \"enabled\": true,
      \"email\": \"$username@example.com\",
      \"firstName\": \"$username\",
      \"credentials\": [{\"type\": \"password\", \"value\": \"$password\", \"temporary\": false}]
    }"

  USER_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/kube-lab/users?username=$username" | jq -r '.[0].id')
  GROUP_ID=$(curl -s -H "Authorization: Bearer $ADMIN_TOKEN" "$KEYCLOAK_URL/admin/realms/kube-lab/groups?search=$group" | jq -r '.[0].id')

  curl -s -X PUT "$KEYCLOAK_URL/admin/realms/kube-lab/users/$USER_ID/groups/$GROUP_ID" \
    -H "Authorization: Bearer $ADMIN_TOKEN"
}

create_user "alice.admin" "password123" "k8s-cluster-manager-platform-admin"
create_user "bob.viewer" "password123" "k8s-cluster-workload-developer-readonly"
create_user "ci.deployer" "password123" "k8s-cluster-manager-ci-deployer"

echo "=== Keycloak Setup Complete ==="
echo "Issuer URL: $KEYCLOAK_URL/realms/kube-lab"
