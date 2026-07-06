<div align="center">
  <h1>Fixit</h1>
  <p><strong>Fix typos and polish phrasing in any macOS app with one hotkey.</strong></p>
  <p>Select text anywhere, press a shortcut, and Fixit rewrites it in place using any model on OpenRouter.</p>

  ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-brightgreen)
  ![Swift](https://img.shields.io/badge/Swift-6.0-orange)
</div>

---

<!-- DEMO VIDEO: record a short clip (select sloppy text → press ⌘⇧1 → corrected text replaces it)
     and drop it here. Easiest: drag the .mp4 into this file in the GitHub web editor and it will
     host it for you. Or commit a GIF to docs/assets/demo.gif and uncomment the line below. -->
<!-- ![Fixit demo](docs/assets/demo.gif) -->
> 🎬 _Demo video coming soon._

## Features

- ⚡ **Works everywhere** — system-wide hotkeys fix selected text in any app: Slack, Mail, your browser, your editor. Nothing selected? Fixit falls back to your clipboard.
- ✍️ **Three built-in styles** — sound native (`⌘⇧1`), rewrite aggressively (`⌘⇧2`), or correct minimally (`⌘⇧3`), plus a style picker on `⌘⇧0`.
- 🎛️ **Fully customizable** — every style is just a Markdown prompt and a shortcut. Edit, rename, add, or remove styles right in Settings.
- 📡 **Streaming with cancel** — watch the fix arrive token by token; press Esc to cancel mid-flight.
- 🤖 **Bring your own model** — talks directly to [OpenRouter](https://openrouter.ai), so you can use any model and pay only for what you use. No subscription, no middleman server.
- 🔐 **Keys stay in your Keychain** — the API key and model are stored in the macOS login Keychain, not in plain-text config.
- 👻 **Lightweight** — a small menu-bar app with no Dock icon, plus a CLI mode for scripting and testing.

## How it works

1. Select text in any app.
2. Press a style shortcut (e.g. `⌘⇧1`).
3. Fixit sends the selection to your chosen model and shows the result.
4. Confirm, and the fixed text replaces your selection.

## Install

There are no prebuilt releases yet — building from source takes about two minutes:

<!-- TODO: update the clone URL once the repo is published -->
```sh
git clone https://github.com/<you>/fixit.git
cd fixit
./scripts/create-signing-cert.sh   # one-time: create a local signing identity
make trust-signing                 # one-time: allow codesign to use it without prompts
make deploy                        # build and install to /Applications
```

To use your own signing identity instead:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (...)" make deploy
```

See [BUILDING.md](BUILDING.md) for details, troubleshooting, and manual steps.

### First run

On first launch Fixit opens a short setup guide: grant the **Accessibility** permission (used only to copy your selection and paste the result), pick a provider, paste your API key (e.g. an [OpenRouter key](https://openrouter.ai/keys)), and test a sample fix. You can rerun it anytime from **Setup Guide…** in the menu bar, and tweak everything else (styles, shortcuts, launch at login) in **Settings…**.

That's it — select some text and press `⌘⇧1`.

## Configuration

The Settings window covers the basics: API key, model, and each style's shortcut and prompt.

For more control, Fixit reads `~/.config/fixit/config.json` — see [`config/config.example.json`](config/config.example.json) for the full shape. Styles are plain Markdown prompt files, so adding a style is: write a prompt, add an entry with a shortcut, done.

<details>
<summary>Development overrides (.env, environment variables)</summary>

For development, Fixit falls back to `.env`, your shell environment, or `~/.config/fixit/.env`:

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

If no Fixit config exists yet, Fixit falls back to an old `~/.config/word-fixer` config.

</details>

## CLI

Fixit also runs from the terminal, handy for scripting or trying a prompt without touching your selection. From the menu-bar app, choose **Install Command Line Tool…** to install `/usr/local/bin/fixit`.

```sh
fixit fix --style native --text "lets create a new project on this folder"
```

Available commands:

```sh
fixit fix [--style native] [--text "text to fix"]  # reads stdin when --text is omitted
fixit styles                                      # prints: <id><tab><label>
fixit config                                      # prints non-secret resolved settings
fixit version
```

When running from source, use `swift run Fixit cli ...`, for example `swift run Fixit cli styles`. The old `swift run Fixit --fix ...` form still works as a deprecated alias for `swift run Fixit cli fix ...`.

## Requirements

- macOS 13 or later
- An [OpenRouter](https://openrouter.ai) API key
- Accessibility permission (to read the selection and paste the result)

## Acknowledgements

Fixit is inspired by [Word Fixer](https://github.com/HazAT/word-fixer-app) by HazAT.
