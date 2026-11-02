#!/usr/bin/env bash
# Signs an app bundle and the Sparkle code inside it, from the inside out, then checks the signature.
#   sign-app.sh APP IDENTITY
# IDENTITY "-" signs ad hoc. A "Developer ID Application" identity also gets the hardened runtime and a
# secure timestamp, which notarization requires. scripts/build-app.sh and the release workflow's sign job
# both use this script, so a local build and a release sign the same parts in the same order.
set -euo pipefail
usage="usage: sign-app.sh APP IDENTITY"
APP_DIR="${1:?$usage}"
CODE_SIGN_IDENTITY="${2:?$usage}"

if [[ "$CODE_SIGN_IDENTITY" == "Developer ID Application"* ]]; then
  CODESIGN_FLAGS=(--options runtime --timestamp)
else
  CODESIGN_FLAGS=(--timestamp=none)
fi

SPARKLE_EMBEDDED="$APP_DIR/Contents/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE_EMBEDDED/Versions/B"
if [[ -e "$SPARKLE_VERSION/XPCServices/Downloader.xpc" ]]; then
  codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
fi
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$SPARKLE_VERSION/XPCServices/Installer.xpc"
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$SPARKLE_VERSION/Autoupdate"
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$SPARKLE_VERSION/Updater.app"
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$SPARKLE_EMBEDDED"
codesign --force --sign "$CODE_SIGN_IDENTITY" "${CODESIGN_FLAGS[@]}" "$APP_DIR"
codesign --verify --strict --verbose=2 "$APP_DIR"
