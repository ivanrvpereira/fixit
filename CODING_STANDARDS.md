# Coding Standards

Reviewers apply these rules to every Swift change in Fixit. They cover judgement calls that the compiler and `swift format` cannot check. Build commands, boundaries, and commit rules live in `AGENTS.md` and `CONTRIBUTING.md`.

Each rule has a reason. Use the reason to decide cases the rule does not name. When a change breaks a rule on purpose, the code must have a comment that says why.

## Baseline: Swift 6.2

The target is Swift 6.2 in the Swift 6 language mode, with approachable concurrency turned on for the `Fixit` target:

```swift
// swift-tools-version: 6.2
swiftSettings: [
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
]
```

Use only language and library features that ship in Swift 6.2 and run at the macOS 13 deployment target. A feature from Swift 6.3 or 6.4 can compile on a newer local toolchain and still break CI or a contributor's build. Examples are `weak let` in `Sendable` types, `~Sendable`, and task cancellation shields. Some Swift 6.2 APIs also need a newer OS: `Task.immediate` requires macOS 26, so it needs an `@available` guard and a fallback.

If `Package.swift` and the CI runner do not have these settings yet, explicit `@MainActor` annotations are still correct. Remove them in the same change that turns the settings on.

## Concurrency

Fixit is an AppKit app. Almost all of its code reads or changes UI state, the pasteboard, or the Accessibility API, and all of that runs on the main thread.

- **Main actor by default.** Write code without isolation annotations and let `.defaultIsolation(MainActor.self)` put it on the main actor. A new `@MainActor` annotation in this target is redundant. Remove it. Why: one default is easier to review than 17 scattered annotations.
- **`@concurrent` for work that must leave the main thread.** Use it for CPU-heavy or blocking work, such as decoding a large response or reading large files. Why: with `NonisolatedNonsendingByDefault`, an `async` function runs on the caller's actor. Being `async` does not move work off the main thread.
- **`nonisolated` means "safe from any actor", not "runs in the background".** Use it only for code that touches no main-actor state: pure parsers, value types, constants. Why: `nonisolated` on main-actor state either fails to compile or hides a data race behind an escape hatch.
- **Pure logic and `Codable` types are `nonisolated`.** Declare `ShortcutParser`, `SSELine`, `InlineDiffBuilder`, `CLIParser`, `DotEnv`, and the config and request/response types `nonisolated`. Why: under default isolation and `InferIsolatedConformances`, their `Codable` and `Equatable` conformances become main-actor isolated, and then `FixitTests` and `@concurrent` code cannot decode or compare them.
- **Isolated conformances over workarounds.** When a main-actor type conforms to a protocol, let the conformance be main-actor isolated instead of adding `nonisolated` stubs or `MainActor.assumeIsolated` calls. With `InferIsolatedConformances` on, the compiler infers this. Write `extension Foo: @MainActor SomeProtocol` only while the setting is off, or where it makes the intent clearer. Why: the compiler checks an isolated conformance, but it cannot check a workaround.
- **Structured concurrency first.** Prefer `async let` and task groups, whose lifetime ends with their scope. Every unstructured `Task {}` answers three questions in the code: who owns it, what cancels it, and where its errors go. `currentFixTask` in `AppController` is the model: the controller stores the task, the overlay's cancel action cancels it, and failures go to `handleTriggerError`. A `Task {}` that nobody stores or cancels is a finding unless it is a short hop from an AppKit callback into async code. Why: an untracked task outlives the window or request it belonged to.
- **`Task.detached` needs a comment.** The comment says why the work must ignore the caller's actor, priority, and cancellation. Why: in most cases `@concurrent` does what the author wanted, and keeps cancellation.
- **Cancellation reaches the network.** When the user cancels a fix, the request to the provider stops. Code that streams or loops calls `try Task.checkCancellation()` or checks `Task.isCancelled` between chunks. A cancelled fix never writes text back into the target app. Why: a late result that replaces the user's newer selection destroys their work.
- **Escape hatches need a comment that proves safety.** This covers `@unchecked Sendable`, `nonisolated(unsafe)`, `MainActor.assumeIsolated`, and `@preconcurrency import`. The comment names the lock, queue, or invariant that makes the code safe. Why: these turn off the compiler's data-race checks, so the comment is the only remaining check.
- **Callbacks enter the main actor in one place.** Carbon hotkey handlers, `NSEvent` monitors, and other C or AppKit callbacks are installed by the type that owns them, such as `HotKeyManager`. That type moves the event onto the main actor and hands feature code a plain closure or `async` call. Why: callback isolation is easy to get wrong, so it should be reviewed in one place.
- **Continuations resume exactly once.** When wrapping a completion-handler API in `async`, use `withCheckedContinuation` or `withCheckedThrowingContinuation`, and resume on every path, including errors and cancellation. Why: a continuation that never resumes hangs the task, and one that resumes twice crashes.

## Errors

- **Plain `throws` by default.** Use typed throws (`throws(FixitError)`) only for internal functions whose callers switch over every case, or for functions that only pass through errors from their arguments. Why: typed throws fix the error type into the signature, so it becomes harder to add a new failure later.
- **Fail without crashing on user input, config, files, and the network.** Write `guard let` or `if let`, and throw or return early. Force unwraps, `try!`, implicitly unwrapped optionals (`Type!`), and `fatalError` are allowed only for programmer mistakes that a test or the first launch catches, such as `init(coder:)` on a view that is never loaded from a nib. Why: a crash during a fix loses the user's text and gives them no message to act on.
- **Error messages tell the user what to do next.** A `FixitError` message names the problem and the next step, like the current `missingAPIKey` and `accessibilityRequired` messages. A provider error includes the HTTP status and the provider's own message, with the API key and the user's text removed. Why: the overlay and CLI are the only places where users see what went wrong.
- **`try?` only where failure is truly fine.** Write a comment when it is not obvious, for example "best-effort log write". Why: `try?` hides failures that the user or the debug log should see.

## Privacy and secrets

Fixit handles text that users select in any app, and API keys that cost money.

- **Logs hold metadata, never content.** `Logger.log` (the debug log at `<configDir>/debug.log`) and anything written to stderr record lengths, counts, durations, IDs, and error descriptions. User text, prompts, model output, clipboard contents, and API keys stay out. Why: the debug log is a plain file that users attach to bug reports.
- **CLI output is the product.** `print` in `runCLI()` is correct, because it is the command's output. `print` or `NSLog` in app code is a finding. Route it through `Logger` instead.
- **API keys go through `KeychainStore` or `CredentialStore` only.** Never read the legacy `Fixit` Keychain service. Why: reading an entry that another build created makes macOS ask for the user's password.
- **Endpoints are sanitized before display or logging.** Use `sanitizedEndpoint(_:)` for any base URL shown to the user or written to a log. Why: some providers accept keys or tokens in the URL.

## Config compatibility

Users keep their `~/.config/fixit` folder across releases, and edit it by hand.

- **New config fields are optional in `FixitConfig`.** `RuntimeConfig.resolve` supplies the default, and the rest of the app reads only `RuntimeConfig`. Why: a config written by an older release must still load. A decoding failure here means Fixit does not start at all.
- **Renames keep reading the old key.** Keep the old field as an optional fallback with a comment, like the OpenRouter-era keys in `FixitConfig`. Moving data between stores (for example files to the Keychain) gets a tested migration in the style of `LegacyCredentialsMigration`. Why: silently dropping a user's setting looks like Fixit forgot it.
- **The sample config is the format's source of truth.** Style IDs, prompt paths, and shortcut shapes in code match `config/config.example.json`. A change to the format updates `config/config.example.json` and `config/styles/*.md` in the same change. Why: they are the documentation for the config format.

## Dev and release builds

`make deploy` builds `FixitDev.app` with its own bundle ID and config folder, so it can run next to the Homebrew `Fixit.app`.

- **Read identity from the environment, never from literals.** Take the bundle ID from `Bundle.main.bundleIdentifier`, the config folder from `RuntimeConfig` (which honors `FIXIT_CONFIG_DIR`), and the app name from the bundle. A literal `"dev.fixitapp.fixit"` is allowed only as the fallback for `swift run`, where there is no bundle. Why: a hard-coded identity makes the dev build read and overwrite the user's real config, Keychain entries, or Accessibility permission.

## Structure

All app code lives in `Sources/Fixit/main.swift`, grouped by area.

- **New code goes next to the area it belongs to.** Provider request and response code goes in `OpenAICompatibleClient`. Lifecycle, menu, and hotkey code goes near `AppController` and `HotKeyManager`. CLI-only code goes in `runCLI()`.
- **Pure logic stays separate from AppKit.** Parsing, diffing, prompt building, and config merging live in value types or caseless enums with no AppKit, pasteboard, or Accessibility calls. Why: this logic can then be tested without a running app, and it can be `nonisolated`.
- **Mixed concerns are a finding.** Examples are UI code in the provider client, network calls in a window controller, or config parsing in a view. Why: the single file stays navigable only while each area keeps to its job.

## Testing

Tests use Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`).

- **Pure logic changes come with tests.** Every change to a parser, `InlineDiffBuilder`, `SSELine`, config decoding, or a migration adds or updates a test that shows the new behavior. Why: these are the parts most likely to break quietly, and the cheapest to test.
- **One parameterized test per behavior.** Use `@Test(arguments:)` for many inputs, not one copied test per input. Why: a new edge case is then one line, and each argument reports its own failure.
- **Tests check behavior through the type's API.** They call the same functions the app calls and check results, not private state. Why: tests that follow the implementation break on every refactor and prove nothing.
- **Tests are hermetic.** They use no network, no real Keychain, no real `~/.config/fixit`, and no pasteboard. Use a temporary directory and fake values. Async tests `await` the result and never sleep. Why: tests that touch the user's machine can destroy real config, and sleeps make tests slow and flaky.
- **`#require` for preconditions, `#expect` for checks.** Use `try #require(...)` to unwrap a value the rest of the test needs, and `#expect` for the actual assertions. Why: `#require` stops the test with a clear message instead of failing on a later, unrelated line.

## Naming and API shape

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/): clarity where the code is called matters more than brevity, and argument labels make calls read like plain English. Use the terms in `GLOSSARY.md` when it exists.
