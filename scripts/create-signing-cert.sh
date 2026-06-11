#!/usr/bin/env bash
set -euo pipefail

# Creates a self-signed code signing certificate in the login Keychain.
# A stable named identity keeps macOS Accessibility/TCC permissions across
# rebuilds, unlike ad-hoc signing. Run once, then ./scripts/build-app.sh.
IDENTITY="${1:-${CODE_SIGN_IDENTITY:-Fixit Local Code Signing}}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -Fq "\"$IDENTITY\""; then
  printf 'Signing identity already exists: %s\n' "$IDENTITY"
  exit 0
fi

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

/usr/bin/openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout "$TMP_DIR/key.pem" -out "$TMP_DIR/cert.pem" \
  -config "$TMP_DIR/openssl.cnf" >/dev/null 2>&1

/usr/bin/openssl pkcs12 -export \
  -inkey "$TMP_DIR/key.pem" -in "$TMP_DIR/cert.pem" \
  -name "$IDENTITY" \
  -out "$TMP_DIR/identity.p12" -passout pass:fixit-temp >/dev/null 2>&1

security import "$TMP_DIR/identity.p12" -k "$KEYCHAIN" -P fixit-temp -T /usr/bin/codesign

# Trust the certificate for code signing (macOS shows a password prompt).
if ! security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP_DIR/cert.pem"; then
  printf 'Could not set trust automatically. Open Keychain Access, find "%s",\n' "$IDENTITY" >&2
  printf 'and set Trust > Code Signing to "Always Trust".\n' >&2
  exit 1
fi

printf 'Created signing identity: %s\n' "$IDENTITY"
printf 'Run "make trust-signing" to let codesign use the key without prompts.\n'
