# Security Policy

## How Fixit handles secrets

- API keys are stored in your macOS login Keychain, one entry per provider. Only Fixit can read them without asking you.
- Fixit 0.8.0 moves keys from the old `~/.config/fixit/credentials.json` into the Keychain the first time it needs a key, then deletes that file.
- Keys can alternatively be supplied via environment variables or a local
  `.env` file, which is ignored by git and must never be committed.
- Selected text is sent only to the provider endpoint you configure; Fixit
  has no telemetry or analytics.

## Release integrity

- Release builds are made on GitHub Actions, signed with an Apple Developer ID, use the hardened runtime, and are notarized by Apple.
- In-app updates come from a Sparkle appcast. Sparkle checks the EdDSA signature of each update before it installs the update.
- The Homebrew cask verifies the downloaded archive's SHA-256 against the
  value published with each release.

## Reporting a vulnerability

Please report security issues privately via
[GitHub Security Advisories](../../security/advisories/new) rather than
opening a public issue. You should receive a response within a few days.
