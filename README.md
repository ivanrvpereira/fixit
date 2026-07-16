<div align="center">
  <img src="Resources/FixitLogo.png" alt="Fixit logo" width="128" height="128">
  <h1>Fixit</h1>
  <p><strong>Fix typos and polish phrasing in any macOS app with one hotkey.</strong></p>
  <p>Select text anywhere, press a shortcut, and Fixit rewrites it in place using OpenRouter, Groq, Gemini, Mistral, or a free local model via Ollama.</p>

  ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-brightgreen)
  ![Swift](https://img.shields.io/badge/Swift-6.0-orange)
  ![License](https://img.shields.io/badge/license-MIT-blue)
</div>

---

<!-- DEMO VIDEO: record a short clip (select sloppy text → press ⌘⇧1 → corrected text replaces it)
     and drop it here. Easiest: drag the .mp4 into this file in the GitHub web editor and it will
     host it for you. Or commit a GIF to docs/assets/demo.gif and uncomment the line below. -->
<!-- ![Fixit demo](docs/assets/demo.gif) -->
> 🎬 _Demo video coming soon._

## Features

- ⚡ **Works everywhere** — system-wide hotkeys fix selected text in any app: Slack, Mail, your browser, your editor. Nothing selected? Fixit falls back to your clipboard.
- ✍️ **Three built-in styles** — sound native (`⌘⇧1`), proofread (`⌘⇧2`), or make professional (`⌘⇧3`), plus a style picker on `⌘⇧0`.
- 🎛️ **Fully customizable** — every style is just a Markdown prompt and a shortcut. Edit, rename, add, or remove styles right in Settings.
- 📡 **Streaming with cancel** — watch the fix arrive token by token; press Esc to cancel mid-flight.
- 🤖 **Bring your own model** — pick a provider: [OpenRouter](https://openrouter.ai), [OpenAI](https://platform.openai.com), [Groq](https://console.groq.com), [Gemini](https://aistudio.google.com), [Mistral](https://console.mistral.ai), [Cerebras](https://cloud.cerebras.ai), local [Ollama](https://ollama.com), or any OpenAI-compatible endpoint. No subscription, no middleman server. Free tiers cover casual use, and local Ollama needs no account at all.
- 🔐 **Keys stay in your Keychain** — the API key is stored in the macOS login Keychain, not in plain-text config.
- 👻 **Lightweight** — a small menu-bar app with no Dock icon, plus a CLI mode for scripting and testing.

## How it works

1. Select text in any app.
2. Press a style shortcut (e.g. `⌘⇧1`).
3. Fixit sends the selection to your chosen model and shows the result.
4. Confirm, and the fixed text replaces your selection.

## Install

```sh
brew tap ivanrvpereira/tap
brew trust ivanrvpereira/tap   # Homebrew 6+: allow loading this third-party tap
brew install --cask fixit
```

To upgrade to new versions later:

```sh
brew upgrade --cask fixit
```

<details>
<summary>Build from source instead</summary>

The build itself takes about two minutes; if you don't have the Xcode Command Line Tools yet, installing them first is a large one-time download:

```sh
xcode-select --install             # one-time: install the Xcode Command Line Tools (skip if already installed)
git clone https://github.com/ivanrvpereira/fixit.git
cd fixit
./scripts/create-signing-cert.sh   # one-time: create a local signing identity (no prompts)
make deploy                        # build and install to /Applications
```

To use your own signing identity instead:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (...)" make deploy
```

See [BUILDING.md](BUILDING.md) for details, troubleshooting, and manual steps.

</details>

### First run

On first launch Fixit opens a short setup guide: grant the **Accessibility** permission (used only to copy your selection and paste the result), pick a provider, paste your API key (the default is Groq — [grab a free key](https://console.groq.com/keys), no card needed; local Ollama needs no key at all), and test a sample fix. You can rerun it anytime from **Check Setup…** in the menu bar, and tweak everything else (styles, shortcuts, launch at login) in **Settings…**.

That's it — select some text and press `⌘⇧1`.

## Configuration

The Settings window covers the basics: API key, model, and each style's shortcut and prompt.

### Which model?

Fixit rewrites short selections, so small, fast models ("mini", "flash", "small") are ideal — bigger models add latency, not better proofreading. Each provider comes with a sensible default, so you can leave the model field alone:

| Provider | Default model | Free tier |
|---|---|---|
| [Groq](https://console.groq.com) | `openai/gpt-oss-120b` | ~1,000 req/day on the default model, no card needed |
| [OpenRouter](https://openrouter.ai) | `openai/gpt-4.1-mini` | `meta-llama/llama-3.3-70b-instruct:free` (~50–200 req/day) |
| [Gemini](https://aistudio.google.com) | `gemini-3.5-flash` | ~1,500 req/day |
| [Mistral](https://console.mistral.ai) | `mistral-small-latest` | free tier, no card needed |
| [Cerebras](https://cloud.cerebras.ai) | `gpt-oss-120b` | ~1M tokens/day |
| [OpenAI](https://platform.openai.com) | `gpt-4.1-mini` | paid only |
| [Ollama](https://ollama.com) | `llama3.2` | fully local, no account or key |

No key yet? Grab a free **Groq** key — a generous free tier and the fastest responses, which is the whole experience in a select-and-fix tool:

- **Most powerful on the free tier:** `openai/gpt-oss-120b` (the default) — OpenAI's open-weight 120B model, still fast on Groq's LPU hardware.
- **Fastest:** `llama-3.3-70b-versatile` — hundreds of tokens per second, fixes feel instant.

_Free-tier limits last checked: July 2026._

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

The app also accepts `openRouterModel`, `openRouterBaseURL`, `openRouterReferer`, and `openRouterAppTitle` in `~/.config/fixit/config.json`. To use the checked-in sample prompts instead, copy `config/config.example.json` to `config/config.json` and run with `FIXIT_CONFIG_DIR=$PWD/config`.

If `~/.config/fixit` doesn't exist yet, Fixit falls back to an old `~/.config/word-fixer` config.

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

- macOS 13 or later to run
- macOS 14.5 or later with the Xcode 16 Command Line Tools (Swift 6 toolchain) to build
- An API key for a supported provider (OpenRouter, OpenAI, Groq, Gemini, Mistral, Cerebras), or a local [Ollama](https://ollama.com) install
- Accessibility permission (to read the selection and paste the result)

## Acknowledgements

Fixit is inspired by [Word Fixer](https://github.com/HazAT/word-fixer-app) by HazAT.

## License

[MIT](LICENSE)
