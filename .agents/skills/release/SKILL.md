---
name: release
description: Cut and verify a Fixit release. Use when tagging a version, publishing a release, updating the Homebrew cask or tap, or debugging a failed Release workflow or red tap CI.
---

# Fixit Release

Releases are fully automated from a version tag. Never tag without explicit user approval.

## Cutting a release

1. Preconditions: working tree clean, `main` pushed, tests green (`make test`).
2. Pick the version by semver from the commits since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`): `feat` → minor, `fix`/`docs` only → patch.
3. Tag and push — this is the entire release procedure:

   ```sh
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```

4. Watch the run: `gh run list --workflow=release.yml --limit 1`, then poll
   `gh run view <id> --json status,conclusion,jobs`. No local build is needed.

## What the Release workflow does (.github/workflows/release.yml)

Four jobs, so that no job both holds a secret and runs code from the build. Each job seals its hand-off with `scripts/digest.sh` and passes the digest as a job output; the next job stops on a wrong digest, a changed file, or an extra file. `BUILDING.md` has the job table.

1. **Build app** (no secrets): validates the tag format and stamps `CFBundleShortVersionString` and `CFBundleVersion` from it (Sparkle compares `CFBundleVersion`), builds an ad-hoc signed `Fixit.app` via `scripts/build-app.sh`, and hands it on as a tar.
2. **Sign and notarize** (`release` environment): imports the Developer ID identity into an ephemeral keychain that only `codesign` may use, signs the app via `scripts/sign-app.sh`, notarizes it, and staples its ticket. Packages the stapled app as `Fixit-X.Y.Z.zip`, builds and signs `Fixit-X.Y.Z.dmg`, deletes the keychain, then notarizes and staples the DMG. It never builds or runs the app.
3. **Verify signed app** (no secrets): checks the zip, the DMG, and the app in the DMG with `spctl`, `stapler validate`, `codesign --verify --deep --strict`, and team ID `6C3B6R8MUR`, and runs `Fixit cli version` from the zip. Renders `packaging/homebrew/fixit.rb` (fills `{{VERSION}}`/`{{SHA256}}`) and **lints the rendered cask** with `brew style` in real tap context — template problems (e.g. stanza order) fail the release before anything is published.
4. **Publish release** (`release` environment):
   1. Downloads Sparkle's `generate_appcast`, checks the tarball against the SHA-256 pinned in the workflow, and generates and signs the Sparkle appcast, preserving its release history.
   2. Renders the cask the same way the verify job did.
   3. Creates the GitHub release with the zip, DMG, and cask attached.
   4. Commits `appcast.xml` to `main` — only after the release exists, so the feed never points at missing assets.
   5. Pushes the cask to `Casks/fixit.rb` in `ivanrvpereira/homebrew-tap` via the `TAP_PUSH_TOKEN` secret (fine-grained PAT, Contents read/write on the tap repo only). If the secret is missing the step skips and the cask must be copied manually.
   6. **Verifies the tap**: polls the tap CI check runs on the pushed commit and fails the release run if the tap goes red or doesn't finish within ~20 min.

When the Sparkle package is upgraded in `Package.resolved`, update `SPARKLE_VERSION` and `SPARKLE_SHA256` in the publish job: take the digest GitHub lists for `Sparkle-X.Y.Z.tar.xz` on the Sparkle release page, and check it with `shasum -a 256` on a download.

## Signing and notarization

- CI signs with a Developer ID Application identity from the `DEVELOPER_ID_CERT_P12` and `DEVELOPER_ID_CERT_PASSWORD` secrets in the `release` environment.
- App and DMG notarization use `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, and the raw `.p8` content in `NOTARY_API_KEY_P8`.
- Sparkle appcast signatures use `SPARKLE_ED_PRIVATE_KEY`; never expose or commit any signing secret.
- Rotating the Developer ID identity forces users to re-grant Accessibility, so do not replace it without explicit approval.

## Troubleshooting

- **Notarization fails with HTTP 403 "A required agreement is missing or has expired"**: not a credentials problem. The Account Holder must accept the updated Apple Developer Program License Agreement at developer.apple.com (it can take a while to propagate), then re-run. A 401 instead means a wrong key ID, issuer ID, or a non-Team key.
- **Cask lint fails**: fix `packaging/homebrew/fixit.rb` in this repo (the tap copy is generated). Verify locally by rendering the template into `$(brew --repository ivanrvpereira/tap)/Casks/fixit.rb` and running `brew style ivanrvpereira/tap` (restore the tap file afterwards).
- **Tap CI red after a release**: fix the template here first, then push a corrected rendered cask to the tap — only with explicit user approval; never push to the tap repo otherwise.
- **Tap CI status by hand**: `gh run list --repo ivanrvpereira/homebrew-tap --limit 3`.
- Users upgrade with `brew upgrade --cask fixit`.
