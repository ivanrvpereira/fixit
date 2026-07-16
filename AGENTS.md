# Fixit

## Stack
- Swift Package Manager executable package: Swift tools 6.0, macOS 13+, targets `Fixit` and `FixitTests` in `Package.swift`.
- macOS app/CLI using AppKit, ApplicationServices, Carbon, Foundation, Security, ServiceManagement in `Sources/Fixit/main.swift`.
- Perplexity-checked Swift 6 baseline: SwiftPM commands, built-in `swift format`, Swift Testing for new tests; add SwiftLint only after a repo config/plugin exists.

## Commands
| Task | Command |
|------|---------|
| Build debug | `swift build` |
| Build release | `swift build -c release` |
| CLI smoke test | `swift run Fixit cli fix --style native --text "lets create a new project on this folder"` |
| Build signed app bundle (release shape) | `./scripts/build-app.sh` |
| Build/install local dev app (`FixitDev.app`, own bundle id + config dir) | `make deploy` |
| Run tests | `make test` (wraps `swift test`; fixes Testing.framework paths on CLT-only machines) |

## File-Scoped Commands
| Task | Command |
|------|---------|
| Format Swift file | `swift format format -i Sources/Fixit/main.swift` |
| Check Swift file format | `swift format lint -s Sources/Fixit/main.swift` |

## Structure
- `Sources/Fixit/main.swift` — app, CLI, config, provider client, UI, hotkeys; read/write.
- `Resources/Info.plist` — app bundle metadata; edit only for bundle behavior.
- `config/config.example.json` and `config/styles/*.md` — checked-in sample user config and prompts.
- `scripts/build-app.sh` — release build, app bundle assembly, codesigning.
- `.build/` and `dist/` — generated outputs; regenerate instead of editing.

## Conventions
- Keep to the existing `Fixit` and `FixitTests` targets unless there is a real need for more.
- New config fields flow through `FixitConfig` and `RuntimeConfig.load()` (in `Sources/Fixit/main.swift`) before use.
- Style IDs, prompt paths, and shortcut shapes match `config/config.example.json`.
- Provider request/response changes belong in `OpenAICompatibleClient` in `Sources/Fixit/main.swift`.
- App lifecycle/menu/hotkey changes belong near `AppController` and `HotKeyManager` in `Sources/Fixit/main.swift`.
- CLI-only behavior belongs in `runCLI()` in `Sources/Fixit/main.swift`.

## Releases
- Fully automated from a `v*` tag; read `.agents/skills/release/SKILL.md` before cutting or debugging a release.
- Never tag, regenerate the signing identity, or push to the tap repo without explicit approval.

## Git
- Use conventional commits: `type(scope): description`, imperative mood, under 72 characters.
- Keep commits to one logical change.

## Boundaries

### Always
- Verify Swift changes with `swift build` when the local environment supports SwiftPM sandboxing.
- Use `swift test` when tests exist; write new tests with Swift Testing.
- Keep secrets in Keychain, environment, or ignored `.env` files.

### Ask First
- Adding dependencies, SwiftLint plugins/config, CI, or new package targets.
- Changing `CODE_SIGN_IDENTITY` defaults in `scripts/build-app.sh`.
- Running recursive formatting over the whole repository.

### Never
- Never commit secrets, API keys, `.env`, Keychain exports, or real user config.
- Never overwrite `~/.config/fixit` or `~/.config/word-fixer` from repository tasks.
- Never hand-edit `.build/` or `dist/`.
