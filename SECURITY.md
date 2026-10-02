# Security Policy

## How Fixit handles secrets

- API keys are stored in `~/.config/fixit/credentials.json`, readable only
  by your user (permissions `600`) — the same model as `~/.aws/credentials`
  or the GitHub CLI. Fixit never touches the macOS Keychain; keys saved
  there by versions before 0.6.0 stay untouched and must be re-entered once
  in Settings.
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
