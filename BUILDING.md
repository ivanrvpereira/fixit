# Building Fixit from source

## Prerequisites

- macOS 13 or later
- Xcode Command Line Tools (Swift 6.0 toolchain)

## 1. Create a signing identity (one-time)

Building requires a local code signing identity:

```sh
./scripts/create-signing-cert.sh
```

This creates a self-signed certificate named `Fixit Local Code Signing` in your login Keychain. macOS will ask for your password once to trust it. A stable named identity (instead of ad-hoc signing) means macOS keeps the app's Accessibility permission across rebuilds.

If you prefer to create the certificate manually: open **Keychain Access** → **Certificate Assistant** → **Create a Certificate…**, name it `Fixit Local Code Signing`, set Identity Type to **Self-Signed Root** and Certificate Type to **Code Signing**.

## 2. Build and run

```sh
./scripts/build-app.sh
open "dist/Fixit.app"
```

Or build and install to `/Applications` in one step:

```sh
make deploy
```

Set `CODE_SIGN_IDENTITY` to use a different signing identity.

## Troubleshooting

- **codesign keeps prompting for your Keychain password** — run `make trust-signing` once.
- **Hotkeys don't do anything** — make sure Fixit has Accessibility permission (System Settings → Privacy & Security → Accessibility). Without it the app can't copy the selection or paste the result.

## Debug builds

```sh
swift build              # debug build
swift build -c release   # release build
swift test               # run tests
```

Quick smoke test from the terminal without launching the app:

```sh
swift run Fixit --fix --style native --text "lets create a new project on this folder"
```
