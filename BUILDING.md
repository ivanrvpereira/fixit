# Building Fixit from source

## Prerequisites

- macOS 14.5 or later (the Swift 6.0 toolchain requires Xcode 16, which needs macOS 14.5+; the built app runs on macOS 13+)
- Xcode 16 Command Line Tools (`xcode-select --install`)

## 1. Create a signing identity (one-time)

Building requires a local code signing identity:

```sh
./scripts/create-signing-cert.sh
```

This creates a self-signed certificate named `Fixit Local Code Signing` in a dedicated `fixit-dev-signing` keychain — your login keychain is never touched and there are no password prompts. A stable named identity (instead of ad-hoc signing) means macOS keeps the app's Accessibility permission across rebuilds.

## 2. Build and run

```sh
make build
open "dist/FixitDev.app"
```

Or build and install to `/Applications` in one step:

```sh
make deploy
```

Local builds are the **Fixit Dev** variant (`FixitDev.app`, bundle id
`dev.fixitapp.fixit.dev`, config in `~/.config/fixit-dev`) so they can run
alongside a brew-installed Fixit.app without sharing its Accessibility grant,
config, or install path. macOS treats it as a separate app, so grant
Accessibility once for Fixit Dev too. If you run both at the same time, give
the dev instance different shortcuts in its own config to avoid hotkey clashes.

Running `./scripts/build-app.sh` directly (no env overrides) produces the
release-shaped `dist/Fixit.app` instead. Set `CODE_SIGN_IDENTITY` to use a
different signing identity.

## Releasing

Push a tag like `v0.2.0` and the [release workflow](.github/workflows/release.yml) signs the app with the "Fixit Release Signing" identity (from the `SIGNING_CERT_P12`/`SIGNING_CERT_PASSWORD` repo secrets, created once via `scripts/generate-release-cert.sh`), packages `Fixit-<version>.zip`, and attaches it plus a rendered Homebrew cask to the GitHub release. The workflow then pushes the rendered `fixit.rb` to `Casks/fixit.rb` in the `ivanrvpereira/homebrew-tap` repository using the `TAP_PUSH_TOKEN` secret (a fine-grained PAT with Contents read/write on the tap repo only); if the secret is unset, copy the file manually. Because every release is signed with the same identity, users' Accessibility grants survive upgrades; the cask's postflight only strips the quarantine flag (the app is not notarized) and never touches the user's keychain.

## Troubleshooting

- **codesign prompts or can't find the identity** — re-run `./scripts/create-signing-cert.sh`; it repairs the dedicated keychain, its search-list entry, and the key ACL. If you still have an old `Fixit Local Code Signing` identity in your login keychain, the script prints the commands to remove it.
- **Hotkeys don't do anything** — make sure Fixit has Accessibility permission (System Settings → Privacy & Security → Accessibility). Without it the app can't copy the selection or paste the result.

## Debug builds

```sh
swift build              # debug build
swift build -c release   # release build
swift test               # run tests
```

Quick smoke test from the terminal without launching the app:

```sh
swift run Fixit cli fix --style native --text "lets create a new project on this folder"
```
