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
2. Imports the signing identity into an ephemeral keychain and builds a signed `Fixit.app` via `scripts/build-app.sh`.
3. Packages `Fixit-X.Y.Z.zip` and computes its SHA-256.
4. Renders `packaging/homebrew/fixit.rb` (fills `{{VERSION}}`/`{{SHA256}}`).
5. **Lints the rendered cask** with `brew style` in real tap context — template problems (e.g. stanza order) fail the release before anything is published.
6. Creates the GitHub release with the zip and cask attached.
7. Pushes the cask to `Casks/fixit.rb` in `ivanrvpereira/homebrew-tap` via the `TAP_PUSH_TOKEN` secret (fine-grained PAT, Contents read/write on the tap repo only). If the secret is missing the step skips and the cask must be copied manually.
8. **Verifies the tap**: polls the tap CI check runs on the pushed commit and fails the release run if the tap goes red or doesn't finish within ~20 min.

## Signing

- CI signs with the self-signed identity "Fixit Release Signing" from the `SIGNING_CERT_P12`/`SIGNING_CERT_PASSWORD` repo secrets (created once via `scripts/generate-release-cert.sh`).
- **Never regenerate the identity without explicit approval** — rotating it forces every user to re-grant Accessibility.
- The identity has no Apple team ID; that is why API keys live in `credentials.json` instead of the Keychain (file-keychain items would re-prompt on every upgrade).

## Troubleshooting

- **Cask lint fails**: fix `packaging/homebrew/fixit.rb` in this repo (the tap copy is generated). Verify locally by rendering the template into `$(brew --repository ivanrvpereira/tap)/Casks/fixit.rb` and running `brew style ivanrvpereira/tap` (restore the tap file afterwards).
- **Tap CI red after a release**: fix the template here first, then push a corrected rendered cask to the tap — only with explicit user approval; never push to the tap repo otherwise.
- **Tap CI status by hand**: `gh run list --repo ivanrvpereira/homebrew-tap --limit 3`.
- Users upgrade with `brew upgrade --cask fixit`.
