#!/usr/bin/env bash
set -euo pipefail

# Creates a self-signed code signing identity for local dev builds. A stable
# identity keeps macOS Accessibility/TCC permissions across rebuilds, unlike
# ad-hoc signing.
#
# The identity lives in a dedicated keychain (empty password, never
# auto-locks), so nothing touches the login keychain and no password prompts
# appear — codesign can sign with an untrusted self-signed cert, so no trust
# settings are needed either. Run once, then `make build` / `make deploy`.
IDENTITY="${1:-${CODE_SIGN_IDENTITY:-Fixit Local Code Signing}}"
KEYCHAIN_NAME="fixit-dev-signing.keychain"
KEYCHAIN="$HOME/Library/Keychains/$KEYCHAIN_NAME-db"

if [[ -f "$KEYCHAIN" ]] && security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -Fq "\"$IDENTITY\""; then
  printf 'Signing identity already exists: %s\n' "$IDENTITY"
  exit 0
fi

# A same-named identity elsewhere (e.g. the login keychain, from the old
# version of this script) would make codesign's identity lookup ambiguous.
if security find-identity -p codesigning 2>/dev/null | grep -Fq "\"$IDENTITY\""; then
  printf 'An identity named "%s" already exists in another keychain.\n' "$IDENTITY" >&2
  printf 'Remove the old one first (this may ask for your login password):\n' >&2
  printf '  security find-certificate -c "%s" -p > /tmp/old-cert.pem\n' "$IDENTITY" >&2
  printf '  security remove-trusted-cert /tmp/old-cert.pem 2>/dev/null || true\n' >&2
  printf '  security delete-identity -c "%s"\n' "$IDENTITY" >&2
  printf '  rm /tmp/old-cert.pem\n' >&2
  exit 1
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

if [[ ! -f "$KEYCHAIN" ]]; then
  security create-keychain -p "" "$KEYCHAIN_NAME"
fi
security set-keychain-settings "$KEYCHAIN" # no auto-lock
security unlock-keychain -p "" "$KEYCHAIN"
security import "$TMP_DIR/identity.p12" -k "$KEYCHAIN" -P fixit-temp -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN" >/dev/null

# codesign only finds identities in keychains on the search list; add ours once.
if ! security list-keychains -d user | grep -Fq "$KEYCHAIN_NAME"; then
  existing=()
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%\"}"
    line="${line#\"}"
    existing+=("$line")
  done < <(security list-keychains -d user)
  security list-keychains -d user -s "${existing[@]}" "$KEYCHAIN"
fi

printf 'Created signing identity "%s" in %s\n' "$IDENTITY" "$KEYCHAIN"
printf 'No trust setup or password prompts needed; run "make build" to use it.\n'
