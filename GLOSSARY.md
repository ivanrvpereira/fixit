# Fixit

Fixit is a macOS menu-bar app that rewrites the text a user selects in any app. The user presses a shortcut, an LLM provider rewrites the text, and the user reviews the result before it replaces the selection.

## Language

### Fixing text

**Fix**:
One run of rewriting the original text with a style or a custom instruction, including any refines, until the user accepts, dismisses, or cancels it. In the CLI, a fix ends when the result is printed.
_Avoid_: Correction, rewrite, job

**Style**:
A named way to rewrite text, made of a style prompt and a shortcut, such as "Sound native" or "Proofread".
_Avoid_: Mode, preset, template

**Style prompt**:
The Markdown instructions that a style gives the model.
_Avoid_: Template, system prompt

**Custom instruction**:
A one-time instruction that the user types in place of a style, such as "translate to English".
_Avoid_: Ad-hoc style, free prompt

**Refine**:
To apply a custom instruction to a fix's result, before accepting it.
_Avoid_: Re-fix, iterate

**Shortcut**:
A system-wide key combination that starts a fix with one style, or opens the style picker.
_Avoid_: Hotkey, keybinding

**Style picker**:
The panel where the user chooses a style or types a custom instruction for the original text.
_Avoid_: Chooser, style menu

### Text and apps

**Selection**:
The text the user has highlighted in the target app when a fix starts.
_Avoid_: Highlighted text, input

**Target app**:
The app that holds the selection, and that receives the result.
_Avoid_: Source app, host app, frontmost app

**Clipboard fallback**:
A fix of the clipboard's text, used when Fixit cannot copy a selection from the target app. The review says the text came from the clipboard, and accepting puts the result on the clipboard instead of replacing text.
_Avoid_: Paste mode, clipboard mode

**Original text**:
The text a fix starts from: the selection, or the clipboard text in a clipboard fallback.
_Avoid_: Source text, input

**Result**:
The text the model returns for a fix.
_Avoid_: Output, suggestion, fixed text

### Reviewing a result

**Overlay**:
The floating panel that shows a fix while it runs and while the user reviews it.
_Avoid_: Popup, HUD, window

**Review**:
The step where the user reads the result in the overlay and decides what to do with it.
_Avoid_: Preview, confirmation

**Diff**:
The review view that marks the words removed from the original text and added in the result.
_Avoid_: Changes view, comparison

**Accept**:
To end the review by using the result: replace the selection, or, in a clipboard fallback, put the result on the clipboard.
_Avoid_: Apply, confirm

**Copy**:
To put the result on the clipboard while the review stays open. The selection does not change.
_Avoid_: Export, accept

**Replace**:
To write the result over the selection in the target app.
_Avoid_: Paste back, insert

**Dismiss**:
To close the review and keep the original text unchanged.
_Avoid_: Reject, discard

**Cancel**:
To stop the request that is still running. A cancelled fix writes nothing to the target app or the clipboard; a cancelled refine returns to the review of the earlier result.
_Avoid_: Abort, stop

### Providers

**Provider**:
The LLM service that a fix is sent to, such as Groq, OpenRouter, or a local Ollama.
_Avoid_: Backend, vendor, API

**Custom provider**:
A provider with no built-in endpoint, so the user must give one. It works with any OpenAI-compatible service.
_Avoid_: Generic provider, other

**Model**:
The provider's language model that writes the result.
_Avoid_: Engine, LLM

**Endpoint**:
The web address that Fixit sends a provider's requests to. Built-in providers have a default endpoint, and the user can change it without changing the provider.
_Avoid_: Base URL, server

**API key**:
The secret that lets Fixit use a provider on the user's account.
_Avoid_: Token, credential, secret

### Setup and configuration

**Setup guide**:
The first-run steps that grant the Accessibility permission, choose a provider, store the API key, and test a fix. The user can rerun it with **Check Setup…**.
_Avoid_: Onboarding, wizard

**Accessibility permission**:
The macOS permission that lets Fixit copy the selection and replace it.
_Avoid_: AX trust, accessibility access

**Settings**:
The window where the user changes the provider, model, API key, styles, shortcuts, and launch at login.
_Avoid_: Preferences

**Config folder**:
The user's folder that holds `config.json` and the style prompt files, by default `~/.config/fixit`.
_Avoid_: Config dir, settings folder

**Debug log**:
A file in the config folder that records what happened during fixes, such as timings, lengths, and errors, so users can attach it to bug reports.
_Avoid_: Trace, history

### Builds

**Release build**:
The signed `Fixit.app` that users install from the DMG or Homebrew, and that updates itself.
_Avoid_: Production build, stable

**Dev build**:
`FixitDev.app`, a local build with its own identity and config folder, so it runs next to the release build.
_Avoid_: Debug build, local app

**CLI**:
The `fixit` terminal command, which fixes text given as an argument or on standard input.
_Avoid_: Command line tool, terminal mode
