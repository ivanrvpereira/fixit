# Fixit

A small macOS word-fixing app that calls OpenRouter directly.

## What it does

- Uses `~/.config/fixit/config.json` for styles and shortcuts.
- Falls back to the old `~/.config/word-fixer` config if no Fixit config exists yet.
- Registers global hotkeys from the style config, e.g. `Command+Shift+1` and `Command+Shift+2`.
- Captures selected text, sends it to OpenRouter, shows the result, and replaces the selection when you confirm.

## Configuration

Use the status bar menu's **Settings…** item to save your OpenRouter API key and model name in your macOS login Keychain. The same settings window also lets you edit each style's shortcut and prompt.

For development, Fixit still falls back to `.env`, your shell environment, or `~/.config/fixit/.env`:

```sh
OPENROUTER_API_KEY=...
OPENROUTER_MODEL=openai/gpt-4.1-mini
```

Optional non-secret settings:

```sh
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1/chat/completions
OPENROUTER_REFERER=https://example.com
OPENROUTER_APP_TITLE=Fixit
```

The app also accepts `openRouterModel`, `openRouterBaseURL`, `openRouterReferer`, and `openRouterAppTitle` in `~/.config/fixit/config.json`. A model stored in Keychain takes precedence over the model in config. To use the checked-in sample prompts instead, copy `config/config.example.json` to `config/config.json` and run with `FIXIT_CONFIG_DIR=$PWD/config`.

## Test from the terminal

```sh
swift run Fixit --fix --style native --text "lets create a new project on this folder"
```

## Build the macOS app

Building requires a local code signing identity (one-time setup):

```sh
./scripts/create-signing-cert.sh
```

This creates a self-signed certificate named `Fixit Local Code Signing` in your login Keychain. macOS will ask for your password once to trust it. A stable named identity (instead of ad-hoc signing) means macOS keeps the app's Accessibility permission across rebuilds.

If you prefer to create the certificate manually: open **Keychain Access** → **Certificate Assistant** → **Create a Certificate…**, name it `Fixit Local Code Signing`, set Identity Type to **Self-Signed Root** and Certificate Type to **Code Signing**.

Then build and run:

```sh
./scripts/build-app.sh
open "dist/Fixit.app"
```

Or `make deploy` to build and install to `/Applications`. Set `CODE_SIGN_IDENTITY` to use a different signing identity. Run `make trust-signing` once if codesign keeps prompting for your Keychain password.

macOS must grant Accessibility permission so the app can copy and paste selected text.

## Acknowledgements

Fixit is inspired by [Word Fixer](https://github.com/HazAT/word-fixer-app) by HazaT.
