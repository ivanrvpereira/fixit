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

Push a tag like `v0.8.0`. The [release workflow](.github/workflows/release.yml) signs `Fixit.app` with the Developer ID Application certificate, notarizes and staples the app and the DMG, and attaches `Fixit-<version>.zip`, `Fixit-<version>.dmg`, `Fixit.dmg`, and the rendered Homebrew cask to a GitHub release. Then it commits the signed Sparkle `appcast.xml` to `main` and pushes the cask to `Casks/fixit.rb` in `ivanrvpereira/homebrew-tap`. The [release skill](.agents/skills/release/SKILL.md) has the full step list and troubleshooting.

The workflow has four jobs, so that no job both holds a secret and runs code from the build:

| Job | Secrets | What it does |
|---|---|---|
| **Build app** | none | Stamps the tag's version, builds an ad-hoc signed `Fixit.app` with `scripts/build-app.sh` (SwiftPM and the Sparkle package), and hands it on as a tar, which keeps the file modes and the symlinks in `Sparkle.framework`. |
| **Sign and notarize** | signing, notary | Signs the app with `scripts/sign-app.sh` and the Developer ID identity (only `codesign` may use the key), notarizes and staples it, packs the zip, makes and signs the DMG, deletes the signing keychain, then notarizes and staples the DMG. It never runs SwiftPM, the build script, or the app. |
| **Verify signed app** | none | Checks the zip and DMG as Gatekeeper would: signatures, team ID `6C3B6R8MUR`, stapled tickets, and Gatekeeper acceptance. Runs `Fixit cli version` from the zip, and lints the rendered cask with `brew style`. |
| **Publish release** | Sparkle, tap | Downloads Sparkle's `generate_appcast` and checks it against a pinned SHA-256, signs the appcast, creates the release, commits `appcast.xml` to `main` after the release exists, pushes the cask to the tap, and waits for the tap's CI. |

Each job seals what it hands on with `scripts/digest.sh`, which writes a `SHA256SUMS` file, and passes the digest of that file to the next job as a job output. The next job stops if the digest, a file, or the list of files does not match, so a file swapped between jobs is never signed or published. `scripts/digest-test.sh` tests the script.

The sign and publish jobs read these secrets from the `release` environment (Settings > Environments). Only runs from `v*` tags can use the environment; GitHub refuses a run from a branch. Set a secret there with `gh secret set NAME --env release`, not as a repository secret:

| Secret | Purpose |
|---|---|
| `DEVELOPER_ID_CERT_P12`, `DEVELOPER_ID_CERT_PASSWORD` | Developer ID Application certificate with its private key (base64 `.p12`) and the `.p12` password |
| `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, `NOTARY_API_KEY_P8` | App Store Connect **Team** API key for `notarytool` (individual keys cannot notarize). Upload the raw `.p8` file, not base64 |
| `SPARKLE_ED_PRIVATE_KEY` | Signs the Sparkle appcast |
| `TAP_PUSH_TOKEN` | Fine-grained PAT with Contents read/write on the tap repository only. If it is not set, copy `fixit.rb` to the tap manually |

Keep the same Developer ID certificate for all releases. A different signing identity makes users grant Accessibility again.

## Troubleshooting

- **codesign prompts or can't find the identity** — re-run `./scripts/create-signing-cert.sh`; it repairs the dedicated keychain, its search-list entry, and the key ACL. If you still have an old `Fixit Local Code Signing` identity in your login keychain, the script prints the commands to remove it.
- **macOS asks for your password when a dev build reads the API key** — local builds use a self-signed certificate instead of an Apple team ID, so the Keychain ties each entry to the exact build that created it. After a rebuild, macOS asks once; click **Always Allow**. To avoid the prompt, don't save a key in Fixit Dev and put it in `~/.config/fixit/.env` instead (for example `GROQ_API_KEY=...`).
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
