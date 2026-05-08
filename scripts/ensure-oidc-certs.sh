#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
CERT_DIR="$REPO_ROOT/certs"

CA_KEY="$CERT_DIR/oidc-ca.key"
CA_CRT="$CERT_DIR/oidc-ca.crt"
SERVER_KEY="$CERT_DIR/oidc-server.key"
SERVER_CRT="$CERT_DIR/oidc-server.crt"
SERVER_CSR="$CERT_DIR/oidc-server.csr"
SERVER_EXT="$CERT_DIR/oidc-server.ext"

mkdir -p "$CERT_DIR"

if ! command -v openssl >/dev/null 2>&1; then
  echo "Error: openssl is required to generate local OIDC certificates."
  exit 1
fi

if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CRT" ]; then
  echo "Generating local OIDC CA..."
  openssl genrsa -out "$CA_KEY" 4096 >/dev/null 2>&1
  openssl req -x509 -new -nodes -key "$CA_KEY" -sha256 -days 3650 \
    -out "$CA_CRT" -subj "/CN=kind-oidc-local-ca" >/dev/null 2>&1
fi

if [ ! -f "$SERVER_KEY" ] || [ ! -f "$SERVER_CRT" ]; then
  echo "Generating local OIDC server certificate for host.docker.internal..."
  openssl genrsa -out "$SERVER_KEY" 2048 >/dev/null 2>&1
  openssl req -new -key "$SERVER_KEY" -out "$SERVER_CSR" \
    -subj "/CN=host.docker.internal" >/dev/null 2>&1

  cat > "$SERVER_EXT" <<EOF
subjectAltName = DNS:host.docker.internal
extendedKeyUsage = serverAuth
keyUsage = digitalSignature,keyEncipherment
EOF

  openssl x509 -req -in "$SERVER_CSR" -CA "$CA_CRT" -CAkey "$CA_KEY" \
    -CAcreateserial -out "$SERVER_CRT" -days 825 -sha256 -extfile "$SERVER_EXT" >/dev/null 2>&1
  rm -f "$SERVER_CSR" "$SERVER_EXT"
fi

echo "OIDC certs ready in $CERT_DIR"
