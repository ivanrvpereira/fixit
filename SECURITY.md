# Security Policy

## How Fixit handles secrets

- API keys are stored in the **macOS Keychain**, never on disk in plain text.
- Keys can alternatively be supplied via environment variables or a local
  `.env` file, which is ignored by git and must never be committed.
- Selected text is sent only to the provider endpoint you configure; Fixit
  has no telemetry or analytics.

## Release integrity

- Release binaries are built and signed on GitHub Actions with a stable
  project signing identity; installing never modifies your keychain.
- The Homebrew cask verifies the downloaded archive's SHA-256 against the
  value published with each release.

## Reporting a vulnerability

Please report security issues privately via
[GitHub Security Advisories](../../security/advisories/new) rather than
opening a public issue. You should receive a response within a few days.
