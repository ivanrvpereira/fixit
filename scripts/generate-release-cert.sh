#!/usr/bin/env bash
set -euo pipefail

# Generates the self-signed release signing identity used by the GitHub
# release workflow. Runs entirely on disk in a temp dir: no keychain is
# touched, locally or otherwise. The identity is stored as two GitHub
# Actions secrets:
#
#   SIGNING_CERT_P12       base64-encoded .p12 (cert + private key)
#   SIGNING_CERT_PASSWORD  password protecting the .p12
#
# Run once. Re-running creates a NEW identity, which changes the app's code
# signature and makes every user re-grant Accessibility on their next
# upgrade — only rotate if the key may have leaked.

IDENTITY="${1:-Fixit Release Signing}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat >"$TMP_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
basicConstraints = critical,CA:FALSE
EOF

P12_PASSWORD="$(openssl rand -hex 24)"

/usr/bin/openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP_DIR/key.pem" -out "$TMP_DIR/cert.pem" \
  -config "$TMP_DIR/openssl.cnf" >/dev/null 2>&1

/usr/bin/openssl pkcs12 -export \
  -inkey "$TMP_DIR/key.pem" -in "$TMP_DIR/cert.pem" \
  -name "$IDENTITY" \
  -out "$TMP_DIR/identity.p12" -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

if command -v gh >/dev/null 2>&1; then
  base64 -i "$TMP_DIR/identity.p12" | gh secret set SIGNING_CERT_P12
  printf '%s' "$P12_PASSWORD" | gh secret set SIGNING_CERT_PASSWORD
  printf 'Stored SIGNING_CERT_P12 and SIGNING_CERT_PASSWORD as repo secrets.\n'
  printf 'Identity: %s (valid 10 years)\n' "$IDENTITY"
else
  printf 'gh not found; set the secrets manually:\n\n'
  printf 'SIGNING_CERT_P12:\n%s\n\n' "$(base64 -i "$TMP_DIR/identity.p12")"
  printf 'SIGNING_CERT_PASSWORD:\n%s\n' "$P12_PASSWORD"
fi
