#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT/dist/Fixit.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ICON_SOURCE="$ROOT/Resources/FixitLogo.png"
ICONSET="$APP_DIR/Fixit.iconset"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Fixit Local Code Signing}"

cd "$ROOT"
swift build -c release

if [[ -e "$APP_DIR" ]]; then
  if command -v trash >/dev/null 2>&1; then
    trash "$APP_DIR"
  else
    rm -rf "$APP_DIR"
  fi
fi
mkdir -p "$MACOS" "$RESOURCES" "$ICONSET"
cp ".build/release/Fixit" "$MACOS/Fixit"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Resources/fixit" "$RESOURCES/fixit"
chmod +x "$RESOURCES/fixit"
cp "$ICON_SOURCE" "$RESOURCES/FixitLogo.png"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$RESOURCES/Fixit.icns"
if command -v trash >/dev/null 2>&1; then
  trash "$ICONSET"
else
  rm -rf "$ICONSET"
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$CODE_SIGN_IDENTITY\""; then
  printf 'Missing code signing identity: %s\n' "$CODE_SIGN_IDENTITY" >&2
  printf 'Run ./scripts/create-signing-cert.sh to create it, or set\n' >&2
  printf 'CODE_SIGN_IDENTITY to an existing local code signing identity.\n' >&2
  exit 1
fi

codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp=none "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

printf 'Built and signed %s\n' "$APP_DIR"
