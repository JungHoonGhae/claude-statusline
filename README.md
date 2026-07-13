<div align="center">
  <h1>claude-statusline</h1>
  <p>A rich statusline for Claude Code — pure bash, no Node.js required.</p>
</div>

<p align="center">
  <strong>English</strong> ·
  <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <a href="#installation"><strong>Install</strong></a> ·
  <a href="#what-it-shows"><strong>Features</strong></a> ·
  <a href="#configuration"><strong>Config</strong></a> ·
  <a href="#how-it-works"><strong>How it works</strong></a> ·
  <a href="#vs-claude-hud"><strong>vs claude-hud</strong></a>
</p>

<p align="center">
  <a href="https://github.com/JungHoonGhae/claude-statusline/stargazers"><img src="https://img.shields.io/github/stars/JungHoonGhae/claude-statusline" alt="GitHub stars" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License" /></a>
  <a href="https://github.com/JungHoonGhae/claude-statusline"><img src="https://img.shields.io/badge/bash-pure-4EAA25.svg?logo=gnubash&logoColor=white" alt="Pure Bash" /></a>
  <a href="https://github.com/JungHoonGhae/claude-statusline"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue.svg" alt="Platform" /></a>
</p>

<p align="center">
  <img src="./screenshot.png" alt="claude-statusline screenshot" width="720" />
</p>

## Why?

The default Claude Code statusline only shows the model name and cost. You don't know:

- How much context you've used until compaction hits
- How close you are to rate limits
- What tools/agents are running in the background
- How much you've spent today, this week, or this month

Even on Max plan where cost isn't a concern, tracking your token usage helps you understand your usage patterns and optimize your workflow.

This statusline fixes all of that.

## What it shows

```
  Fable 5 high ✦ │ ctx 14% ● ○ ○ ○ ○ 143.5K/1M │ oss-qraft (main) │ PR #42 ✓ │ $50.07 · 2h 3m · ~$24/hr +1036 -49
  Session ● ● ● ● ● ● ● ● ○ ○  83% left  Resets in 1h 27m
  Weekly  ● ● ● ● ● ● ● ● ○ ○  83% left  Resets in 3d 23h
  Sonnet  ● ● ● ● ● ● ● ● ● ○  95% left  Resets in 4d 15h
  ✓ Bash×40  ✓ Edit×19  ✓ Read×12  ✓ Write×11  ✓ Grep×2
  ◐ Explore Explore current Qraft codebase
  ─────────────────────────────────────────────
  Today            $227.00 · 264.5M tokens
  Yesterday        $101.77 · 111.7M tokens
  Last 30 Days    $3449.66 · 3.9B tokens
```

| Section | Details |
|---------|---------|
| **Header** | Model + badges (⚡ fast mode, effort level, ✦ thinking, ◑ output style, ⛭ agent), context % with mini-bar and token count (143.5K/1M, marked ⚠200k+ past the premium threshold), project, git branch + dirty + ↑ahead ↓behind, PR # + review state (clickable), session cost · duration · ~$/hr burn rate, lines +/-, optional session name |
| **Compaction Warning** | Red warning when context exceeds critical threshold |
| **Rate Limits** | Session (5h) / Weekly (7d) / per-model buckets (Opus, Sonnet, Fable, … auto-detected) / Extra usage — gauge bar + % left + reset time |
| **Tool Activity** | Running tools, completed tool counts, active agents |
| **Token Costs** | Today / Yesterday / Last 30 days — cost & token count |
| **Budget Alert** | Red warning when daily spending exceeds configured limit |

### Header badges

| Badge | Meaning |
|-------|---------|
| `⚡fast` | Fast mode enabled |
| `high` | Reasoning effort level (low/medium/high/max) |
| `✦` | Extended thinking enabled |
| `◑explanatory` | Active output style (only when not `default`) |
| `⛭security-reviewer` | Active agent (during `--agent` sessions) |
| `⚠200k+` | Past the 200k premium long-context billing threshold (>200k-window models only) |
| `PR #42 ✓` | Open PR — ✓ approved · ● pending · ✗ changes requested · ◌ draft |
| `+1036 -49` | Lines added/removed this session |

Badges only appear when the data exists — e.g. `⚡fast` shows only with fast mode on, `PR #42` only while a PR is open.

### Per-model rate limit buckets

Model-specific weekly buckets are **auto-detected** from the OAuth usage API — whatever buckets Anthropic reports for your plan show up automatically, so new models appear without a script update. They are ordered by model capability (most capable first, `Fable` > `Opus` > `Sonnet` > `Haiku`), and buckets the API reports as `null` (inactive for your plan) are hidden. An `Extra` gauge appears when extra usage credits are enabled on your account.

> Note: which buckets exist depends on your plan and usage. A bucket only appears once that model has tracked usage — most accounts see just one (e.g. `Sonnet`, as above); `Opus` shows once you've used Opus. When more than one is active they sort by capability, and any new model Anthropic adds appears automatically — no update needed.

### Color coding

| | Green | Yellow | Red |
|---|---|---|---|
| **Context** | < 30% | 30–70% | > 70% |
| **Rate limit** | > 50% left | 20–50% left | < 20% left |

## Installation

### Plugin (recommended)

```bash
/plugin marketplace add JungHoonGhae/claude-statusline
/plugin install claude-statusline@claude-statusline
```

Auto-setup on every session start — scripts stay up to date with the plugin.

### Shell

```bash
curl -fsSL https://raw.githubusercontent.com/JungHoonGhae/claude-statusline/main/install-remote.sh | bash
```

<details>
<summary><strong>Other methods</strong></summary>

#### Clone & install

```bash
git clone https://github.com/JungHoonGhae/claude-statusline.git
cd claude-statusline
bash install.sh
```

#### Manual

```bash
cp statusline.sh ~/.claude/statusline-command.sh
cp ccusage-cache.sh ~/.claude/ccusage-cache.sh
chmod +x ~/.claude/statusline-command.sh ~/.claude/ccusage-cache.sh
cp statusline.conf.example ~/.claude/statusline.conf
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

</details>

### Prerequisites

- **jq** and **curl** — the installers auto-install these via your package manager (brew / apt / dnf / yum / pacman / apk)

The token cost section is pure bash + jq (no Node.js). It reads Claude Code's local transcripts directly and prices them with per-model rates from [LiteLLM's pricing database](https://github.com/BerriAI/litellm) — fetched once a day via `curl` and cached. Offline or without `curl`, a built-in price table keeps the section working.

If a dependency goes missing later (e.g. after a container restart), the statusline shows an install hint instead of silently hiding the section.

## Configuration

Edit `~/.claude/statusline.conf` to customize:

```bash
# Toggle sections
SHOW_RATE_LIMITS=true
SHOW_TOOLS=true
SHOW_AGENTS=true
SHOW_CCUSAGE=true

# Header extras
SHOW_CONTEXT_BAR=true
SHOW_BURN_RATE=true
SHOW_GIT_AHEAD=true
SHOW_LINKS=true
SHOW_SESSION_NAME=false

# Context thresholds
CONTEXT_WARN_PCT=30       # Yellow warning
CONTEXT_CRIT_PCT=70       # Red + compaction warning

# Budget alert (0 = disabled)
DAILY_BUDGET=0
```

| Option | Default | Description |
|--------|---------|-------------|
| `SHOW_RATE_LIMITS` | `true` | Session/weekly/per-model rate limit bars |
| `SHOW_TOOLS` | `true` | Tool activity from transcript |
| `SHOW_AGENTS` | `true` | Agent activity from transcript |
| `SHOW_CCUSAGE` | `true` | Daily/monthly token cost stats |
| `SHOW_CONTEXT_BAR` | `true` | Small 5-dot gauge next to ctx % |
| `SHOW_BURN_RATE` | `true` | ~$/hr spend rate in the header |
| `SHOW_GIT_AHEAD` | `true` | ↑ahead ↓behind vs upstream |
| `SHOW_LINKS` | `true` | Clickable PR link (OSC 8; auto-off in tmux) |
| `SHOW_SESSION_NAME` | `false` | Show the `/rename` session name in the header |
| `CONTEXT_WARN_PCT` | `30` | Context % threshold for yellow |
| `CONTEXT_CRIT_PCT` | `70` | Context % threshold for red + compaction warning |
| `DAILY_BUDGET` | `0` | Daily budget alert in USD (0 = disabled) |

Every option can be set in the conf file **or** as an environment variable (the conf
file takes precedence). The statusline also auto-compacts its layout on narrow
terminals using `$COLUMNS`.

See [statusline.conf.example](./statusline.conf.example) for a fully commented template.

## vs claude-hud

| | claude-statusline | [claude-hud](https://github.com/jarrodwatts/claude-hud) |
|---|---|---|
| **Type** | Pure bash scripts | Node.js/TypeScript plugin |
| **Install** | Plugin marketplace, one-liner `curl`, or copy 2 files | Plugin marketplace |
| **Dependencies** | `jq` only | Node.js 18+ |
| **Rate limits** | stdin + OAuth API (model-specific + extra usage) | stdin only |
| **Token costs** | Daily/monthly (transcripts + LiteLLM pricing) | — |
| **Budget alert** | Configurable daily limit | — |
| **Compaction warning** | Context threshold alert | — |
| **Configuration** | Simple KEY=value conf file | JSON config + `/configure` command |
| **Platform** | macOS, Linux, Windows (Git Bash/WSL) | Cross-platform |

## How it works

```
Claude Code stdin (JSON)
  ├── model, effort, thinking, fast_mode, context_window, cost, pr, transcript_path
  └── rate_limits (v2.1.6+)     ← Session/Weekly from stdin
          │
statusline.sh
  ├── stdin rate_limits            Primary source
  ├── OAuth API (cached 2m)        Fallback + per-model buckets (auto-detected) + extra usage
  ├── git CLI                      Branch & dirty state (stdin no longer carries .git)
  ├── Transcript JSONL parsing     Tool & agent activity
  └── ccusage-cache.sh (bg, 10m)  Token cost aggregation (bash+jq, LiteLLM pricing)
          │
stdout → Claude Code displays
```

| Data | Source | Cache |
|------|--------|-------|
| Context / model / effort / PR / cost | stdin (native) | — |
| Session & Weekly limits | stdin `rate_limits` | — |
| Per-model limits (Opus/Sonnet/Fable/…), extra usage | OAuth API | 2 min |
| Git branch & dirty state | `git` CLI (stdin fallback) | — |
| Tool & agent activity | Transcript JSONL | — |
| Token costs | Transcript JSONL + LiteLLM pricing | 10 min (background) |

## Troubleshooting

### Statusline goes blank after a Docker/devcontainer restart

A container restart resets the container filesystem to the image — only mounted volumes (e.g. `~/.claude`) survive. If `jq` was installed inside the running container, it disappears and the statusline stops rendering. Bake the dependencies into your image:

```dockerfile
# Debian/Ubuntu
RUN apt-get update && apt-get install -y jq curl git
# Alpine
RUN apk add --no-cache jq curl git bash
```

Since v1.2.2 the statusline shows `claude-statusline: jq not found` instead of silently going blank.

### Token cost section missing

The Today/Yesterday/Last 30 Days section needs `jq` and Claude Code's local transcripts under `~/.claude/projects`. When it can't run, the statusline shows a dim `✗ ccusage: ...` hint with the reason. The cache refreshes in the background, so the section can take one ~10s refresh cycle to appear after install. Pricing is fetched from LiteLLM via `curl` and cached for a day; without `curl` (or offline) a built-in price table is used instead.

## Platform support

Works on **macOS**, **Linux**, and **Windows** (Git Bash / WSL).

- **macOS**: OAuth token from Keychain (`security` command)
- **Linux**: OAuth token from `~/.claude/.credentials.json` or GNOME Keyring (`secret-tool`)
- **Windows**: OAuth token from `~/.claude/.credentials.json` or `%APPDATA%/Claude/credentials.json`

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history. Recent highlights:

- **1.5.0** — premium long-context `⚠200k+` marker, output-style and agent badges, Korean README
- **1.4.1** — responsive 3-tier layout (`$COLUMNS`-aware), `idle` label for unused buckets, accurate screenshot
- **1.4.0** — header extras: context bar, ~$/hr burn rate, git ↑ahead ↓behind, clickable PR link
- **1.3.0** — auto-install dependencies, surface every silent failure, capability-ordered model buckets
- **1.2.x** — auto-detected per-model rate buckets, ccusage v18 compatibility
- **1.1.0** — v2.1.x stdin support: model badges, context tokens, PR badge, lines +/-

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for how to test
changes and the project guidelines. By participating you agree to the
[Code of Conduct](CODE_OF_CONDUCT.md). To report a security issue, see the
[Security Policy](SECURITY.md).

## Credits

Inspired by [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud).
Token cost tracking inspired by [ryoppippi/ccusage](https://github.com/ryoppippi/ccusage); per-model pricing from [LiteLLM](https://github.com/BerriAI/litellm).

## Support

If this helped your workflow, consider buying me a coffee.

<a href="https://www.buymeacoffee.com/lucas.ghae">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="50">
</a>

## License

MIT

<p align="center">
  <a href="https://www.star-history.com/?repos=JungHoonGhae%2Fclaude-statusline&type=date&legend=top-left">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/image?repos=JungHoonGhae/claude-statusline&type=date&theme=dark&legend=top-left" />
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/image?repos=JungHoonGhae/claude-statusline&type=date&legend=top-left" />
      <img alt="Star History Chart" src="https://api.star-history.com/image?repos=JungHoonGhae/claude-statusline&type=date&legend=top-left" width="600" />
    </picture>
  </a>
</p>
