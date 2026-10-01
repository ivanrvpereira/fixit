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

1. Validates the tag format and stamps `CFBundleShortVersionString` from it.
2. Imports the Developer ID identity into an ephemeral keychain, builds a signed `Fixit.app` via `scripts/build-app.sh`, notarizes it, and staples its ticket.
3. Packages the stapled app as `Fixit-X.Y.Z.zip`, computes its SHA-256, then builds, signs, notarizes, and staples `Fixit-X.Y.Z.dmg`.
4. Generates and signs the Sparkle appcast, preserving its release history.
5. Renders `packaging/homebrew/fixit.rb` (fills `{{VERSION}}`/`{{SHA256}}`).
6. **Lints the rendered cask** with `brew style` in real tap context — template problems (e.g. stanza order) fail the release before anything is published.
7. Creates the GitHub release with the zip, DMG, and cask attached.
8. Commits `appcast.xml` to `main` — only after the release exists, so the feed never points at missing assets.
9. Pushes the cask to `Casks/fixit.rb` in `ivanrvpereira/homebrew-tap` via the `TAP_PUSH_TOKEN` secret (fine-grained PAT, Contents read/write on the tap repo only). If the secret is missing the step skips and the cask must be copied manually.
10. **Verifies the tap**: polls the tap CI check runs on the pushed commit and fails the release run if the tap goes red or doesn't finish within ~20 min.

## Signing and notarization

- CI signs with a Developer ID Application identity from the `DEVELOPER_ID_CERT_P12` and `DEVELOPER_ID_CERT_PASSWORD` repo secrets.
- App and DMG notarization use `NOTARY_API_KEY_ID`, `NOTARY_API_ISSUER_ID`, and the raw `.p8` content in `NOTARY_API_KEY_P8`.
- Sparkle appcast signatures use `SPARKLE_ED_PRIVATE_KEY`; never expose or commit any signing secret.
- Rotating the Developer ID identity forces users to re-grant Accessibility, so do not replace it without explicit approval.

## Troubleshooting

- **Cask lint fails**: fix `packaging/homebrew/fixit.rb` in this repo (the tap copy is generated). Verify locally by rendering the template into `$(brew --repository ivanrvpereira/tap)/Casks/fixit.rb` and running `brew style ivanrvpereira/tap` (restore the tap file afterwards).
- **Tap CI red after a release**: fix the template here first, then push a corrected rendered cask to the tap — only with explicit user approval; never push to the tap repo otherwise.
- **Tap CI status by hand**: `gh run list --repo ivanrvpereira/homebrew-tap --limit 3`.
- Users upgrade with `brew upgrade --cask fixit`.
