# Review Guidelines

Project instructions for reviewing Fixit changes. They add to the general review rubric, and they win where the two disagree.

Fixit is a macOS menu-bar app (Swift 6, AppKit, macOS 13+). It reads the text a user selects in any app, sends it to an LLM provider, and writes the result back into that app. Nearly all code lives in `Sources/Fixit/main.swift`. Two things are at stake in every review: the user's text in the target app, and the user's API keys.

## Before you review

1. Read `CODING_STANDARDS.md`. It holds Fixit's rules and the reason for each one. When a finding breaks one of its rules, name the rule by its bold title, for example "violates **Cancellation reaches the network**".
2. Read `Package.swift`. Some checks below depend on whether the `Fixit` target has `.defaultIsolation(MainActor.self)` turned on yet.

## Priorities in Fixit

Use these levels for Fixit-specific problems. They override the general priority definitions.

- **[P0]** The user loses text or Fixit stops working for existing users:
  - A cancelled, failed, or stale fix writes text into the target app, or replaces a selection the user made after the fix started.
  - The user's clipboard contents are not restored after a capture or replace.
  - A config written by an older release no longer decodes, so Fixit does not start (see **New config fields are optional in `FixitConfig`**).
- **[P1]** Privacy, security, or crash risk:
  - User text, prompts, model output, clipboard contents, or API keys reach `Logger`, stderr, or an error message (see **Logs hold metadata, never content**).
  - Code reads the legacy `Fixit` Keychain service, or stores a key outside `KeychainStore` and `CredentialStore`.
  - A literal bundle ID, config path, or app name makes the dev build touch the real user's config, Keychain, or Accessibility permission (see **Read identity from the environment, never from literals**).
  - AppKit, pasteboard, or Accessibility calls can run off the main thread (see [Concurrency](#concurrency)).
  - A force unwrap, `try!`, or `fatalError` can fire on user input, config, files, or network data.
- **[P2]** Bugs and maintainability:
  - An unstructured `Task` that nobody owns or cancels, or a streaming loop that ignores cancellation. Raise this to P0 when the result can still reach the target app.
  - An escape hatch (`@unchecked Sendable`, `nonisolated(unsafe)`, `MainActor.assumeIsolated`, `@preconcurrency import`, `Unmanaged`) without a comment that proves it is safe.
  - A pure-logic change (parser, `InlineDiffBuilder`, `SSELine`, config decoding, migration) without a test.
  - Mixed concerns, such as UI code in `OpenAICompatibleClient` or network calls in a window controller.
- **[P3]** Naming, API shape, and small cleanups that make the call site clearer.

## Concurrency

Fixit runs almost everything on the main actor. These checks cover the places where the compiler does not protect it.

- **AppKit isolation is partial in the SDK.** `NSApplication`, `NSWindow`, `NSPanel`, and `NSView` are `@MainActor` in the SDK. `NSStatusItem`, `NSMenu`, `NSMenuItem`, `NSPasteboard`, `NSWorkspace`, `NSEvent` monitors, and the `AX*` functions are not, so the compiler accepts them in `nonisolated` or `@concurrent` code. Flag any of these calls in code that can run off the main actor ([NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem), [NSMenu](https://developer.apple.com/documentation/appkit/nsmenu), [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)).
- **C callbacks keep their explicit hop to the main actor.** Under default main-actor isolation, a closure passed to a C API (Carbon `InstallEventHandler`, other `@convention(c)` callbacks) is inferred as main-actor code. If the C API calls it on another thread, there is no compile error and no runtime trap. Flag a change that removes the `Task { @MainActor in … }` hop in `HotKeyManager` or a similar callback because it "now compiles without it" ([migration guide, Unmarked Sendable Closures](https://github.com/swiftlang/swift-migration-guide/blob/main/Guide.docc/IncrementalAdoption.md)).
- **Pure logic and `Codable` types are `nonisolated` once default isolation is on.** With `.defaultIsolation(MainActor.self)` and `InferIsolatedConformances`, a plain `struct Payload: Decodable` gets a main-actor conformance. Decoding it in `nonisolated` or `@concurrent` code, or from the `FixitTests` target, then fails to compile. In the change that turns the settings on, and after it, expect `nonisolated` on parsers, `SSELine`, `InlineDiffBuilder`, `CLIParser`, `DotEnv`, and the `Codable` config and request/response types ([SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md), [SE-0470](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0470-isolated-conformances.md)).
- **Conformances on main-actor types.** Flag `nonisolated` witness stubs or `MainActor.assumeIsolated` used only to satisfy a protocol. Once `InferIsolatedConformances` is on, the compiler infers `@MainActor P`, so the explicit spelling is optional.
- **Features must ship in Swift 6.2 and run on macOS 13.** Some Swift 6.2 APIs need a newer OS. For example, `Task.immediate` requires macOS 26. Flag new concurrency or standard-library APIs that have no `@available` guard and do not run at the macOS 13 deployment target ([SE-0472](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0472-task-start-synchronously-on-caller-context.md)).
- **Unmanaged pointers state their lifetime.** `Unmanaged.passUnretained(self)` passed to a C API needs a comment that names the owner that keeps the object alive for as long as the callback can fire.

## AppKit

- **Status items are stored strongly.** An `NSStatusItem` held only in a local variable disappears from the menu bar. Flag status items that are not kept in a stored property ([NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)).
- **Overlays do not activate Fixit.** Panels shown during a fix use `.nonactivatingPanel`. If Fixit becomes the active app, the target app loses focus and the replacement goes to the wrong place ([nonactivatingPanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel)).
- **Event monitors are removed.** Code that calls `NSEvent.addLocalMonitorForEvents` or `addGlobalMonitorForEvents` stores the returned token and calls `removeMonitor(_:)` when it is done ([addLocalMonitorForEvents](https://developer.apple.com/documentation/appkit/nsevent/addlocalmonitorforevents(matching:handler:))).
- **Pasteboard reads use a change count baseline.** Code that waits for a copy compares `changeCount` against the value returned by `clearContents()`, and restores the user's pasteboard snapshot on every path, including errors and cancellation ([changeCount](https://developer.apple.com/documentation/appkit/nspasteboard/changecount)).
- **Activation is a request.** `NSApplication.activate()` and `NSRunningApplication.activate(options:)` do not guarantee activation. New fixed sleeps after activation need a comment that says they are a timing heuristic ([activate(options:)](https://developer.apple.com/documentation/appkit/nsrunningapplication/activate(options:))).
- **Login item errors reach the user.** `SMAppService.register()` and `unregister()` throw, and `status` can be `.requiresApproval`. Flag code that drops these errors or shows only on and off ([register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register())).
- **Menu actions name their target.** A new `NSMenuItem` with an app action sets `target` explicitly. Standard edit actions such as `selectAll(_:)` correctly use the responder chain with a `nil` target.

## Types and API shape

- **Structs by default, `final class` for AppKit subclasses and identity.** Flag a new class that has no identity, sharing, or Objective-C need, and a new class that is not `final` without a subclass ([Choosing Between Structures and Classes](https://developer.apple.com/documentation/swift/choosing-between-structures-and-classes)).
- **Clarity at the call site.** Apply the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/). Raise a naming finding only when a call site reads wrongly or ambiguously, for example a `Bool` parameter like `fromMenu:` where an enum would name the source.
- **Typed throws follow SE-0413.** Flag `throws(SomeError)` chosen only because the function throws one kind of error ([SE-0413, When to use typed throws](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0413-typed-throws.md#when-to-use-typed-throws)).

## Leave these alone

These patterns are deliberate. Do not report them.

- The string literal `"AXTrustedCheckOptionPrompt"`. Swift 6 rejects `kAXTrustedCheckOptionPrompt` as a global that is not concurrency-safe.
- Explicit `@MainActor` annotations while `Package.swift` has no `.defaultIsolation(MainActor.self)`.
- `Task { @MainActor in … }` used as a short hop from an AppKit or C callback into async code.
- `print` in `runCLI()`. It is the command's output.
- Missing `///` doc comments. The project has not adopted a doc-comment rule.
- No preference to hide the status item. It is Fixit's only entry point, and `LSUIElement` hides the Dock icon.
- Formatting that `swift format` handles.

## Fixit human callouts

Add these to the Human Reviewer Callouts section when they apply, in the same bold style:

- **This change modifies the Swift toolchain or package settings:** changes to `swift-tools-version`, `swiftSettings`, upcoming features, or the CI runner. The `macos-15` CI runner may not have Swift 6.2.
- **This change modifies app identity or signing:** `Resources/Info.plist`, bundle ID, entitlements, or `scripts/build-app.sh`.
- **This change modifies updates:** Sparkle settings, `appcast.xml`, or the release workflow.
- **This change modifies stored credentials:** Keychain service names, `KeychainStore`, `CredentialStore`, or a credential migration.
- **This change modifies the config format:** `FixitConfig` fields, `config/config.example.json`, `config/styles/*.md`, or a config migration.
- **This change modifies system permissions or input:** Accessibility prompts, synthetic key events, hotkey registration, or login items.
- **This change modifies provider traffic:** endpoints, request bodies, headers, or what text is sent to the provider.
