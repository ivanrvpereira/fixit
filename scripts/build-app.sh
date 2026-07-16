#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Variant knobs. Defaults produce the release Fixit.app; the Makefile overrides
# them so local dev builds (FixitDev.app) can coexist with the brew-installed
# app: separate bundle id (own TCC grant) and optional separate config dir.
APP_NAME="${APP_NAME:-Fixit}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-$APP_NAME}"
BUNDLE_ID="${BUNDLE_ID:-dev.fixitapp.fixit}"
APP_CONFIG_DIR="${APP_CONFIG_DIR:-}" # if set, baked into LSEnvironment as FIXIT_CONFIG_DIR

APP_DIR="$ROOT/dist/$APP_NAME.app"
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
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_DISPLAY_NAME" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS/Info.plist"
if [[ -n "$APP_CONFIG_DIR" ]]; then
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$CONTENTS/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :LSEnvironment:FIXIT_CONFIG_DIR string $APP_CONFIG_DIR" "$CONTENTS/Info.plist"
fi
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

# Local dev identities live in a dedicated keychain (see
# scripts/create-signing-cert.sh); unlock it non-interactively so codesign
# never prompts, e.g. after a reboot.
DEV_KEYCHAIN="$HOME/Library/Keychains/fixit-dev-signing.keychain-db"
if [[ "$CODE_SIGN_IDENTITY" != "-" && -f "$DEV_KEYCHAIN" ]]; then
  security unlock-keychain -p "" "$DEV_KEYCHAIN" 2>/dev/null || true
fi

# CODE_SIGN_IDENTITY=- means ad-hoc signing. CI signs with "Fixit Release
# Signing", a self-signed identity that is untrusted on the runner, so check
# without -v (which hides untrusted identities that codesign still accepts).
if [[ "$CODE_SIGN_IDENTITY" != "-" ]] && ! security find-identity -p codesigning | grep -Fq "\"$CODE_SIGN_IDENTITY\""; then
  printf 'Missing code signing identity: %s\n' "$CODE_SIGN_IDENTITY" >&2
  printf 'Run ./scripts/create-signing-cert.sh to create it, or set\n' >&2
  printf 'CODE_SIGN_IDENTITY to an existing local code signing identity.\n' >&2
  exit 1
fi

codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp=none "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"

printf 'Built and signed %s\n' "$APP_DIR"
