# Contributing to Fixit

Thanks for your interest in contributing!

## Getting started

- See [BUILDING.md](BUILDING.md) for build-from-source instructions.
- Build requirements: macOS 14.5+ with the Xcode 16 Command Line Tools (Swift 6 toolchain); the app itself runs on macOS 13+.

## Development

| Task | Command |
|------|---------|
| Build | `swift build` |
| Run tests | `make test` |
| CLI smoke test | `swift run Fixit cli fix --style native --text "lets create a new project on this folder"` |
| Build signed app bundle | `./scripts/build-app.sh` |

## Guidelines

- Keep changes focused; one logical change per pull request.
- Add tests (Swift Testing) for new pure logic where practical.
- Use Conventional Commits: `type(scope): description`, imperative mood,
  under 72 characters (e.g. `fix(settings): validate shortcuts before saving`).
- Never commit secrets, API keys, or `.env` files.

## Reporting issues

Open a GitHub issue with steps to reproduce, your macOS version, and any
relevant log output. For security issues, see [SECURITY.md](SECURITY.md).
