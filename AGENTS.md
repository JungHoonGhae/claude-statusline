# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What this is

A pure-bash statusline for Codex. `statusline.sh` reads the JSON Codex
pipes to a `statusLine` command on **stdin** and prints a multi-line, ANSI-colored
dashboard to **stdout**. No runtime beyond `jq` (+ `curl` and `npx` for optional
sections). Target **bash 3.2** (the macOS default) — avoid `${var^^}`, associative
arrays, and other bash 4+ features.

## Develop & test

There is no build step or test framework. You verify by piping a sample payload:

```bash
echo '{
  "model": {"id": "Codex-fable-5", "display_name": "Fable 5"},
  "cwd": "'"$PWD"'",
  "context_window": {"used_percentage": 14, "context_window_size": 1000000,
    "current_usage": {"input_tokens": 2, "cache_read_input_tokens": 141280, "cache_creation_input_tokens": 2225}},
  "cost": {"total_cost_usd": 24.32, "total_duration_ms": 2563618, "total_lines_added": 1036, "total_lines_removed": 49}
}' | bash statusline.sh
```

- Always `bash -n statusline.sh ccusage-cache.sh install.sh install-remote.sh scripts/*.sh` before committing.
- Force a tier with `COLUMNS=60 ... | bash statusline.sh` (responsive: <100 compact, ≥132 full).
- Regenerate the README image with `scripts/screenshot.sh` (needs `charmbracelet/freeze`); it
  backs up and restores your real `~/.Codex` caches.
- To inspect the live stdin schema, temporarily `tee` `input=$(cat)` to a file in the
  installed `~/.Codex/statusline-command.sh`, then revert.

## Data flow (the big picture)

`statusline.sh` assembles the output from four sources, in priority order:

1. **stdin JSON** (native) — model, `context_window`, `cost`, `pr`, `effort`, `thinking`,
   `fast_mode`, `rate_limits.{five_hour,seven_day}`. This is the primary source.
2. **git CLI** — branch, dirty, and ↑ahead/↓behind. stdin **no longer carries `.git`**
   (v2.1.x), so these are read from the repo at `cwd` directly.
3. **OAuth usage API** (`/api/oauth/usage`, cached 120s in a per-user tmp dir) — fallback
   for Session/Weekly plus **per-model weekly buckets** (`seven_day_opus`, `seven_day_sonnet`,
   …) and `extra_usage`. Token comes from the OS keychain / credentials file via
   `get_oauth_token` (platform-specific).
4. **ccusage** via `ccusage-cache.sh` — daily/monthly token cost, refreshed in the
   background (~10 min) because `npx ccusage` is slow (~5s).

### Conventions that matter

- **Fail loudly, never silently.** A missing dependency or failed external command must
  print a dim hint (e.g. `jq not found`, `✗ ccusage: …`, `idle`), not blank out a section.
  `ccusage-cache.sh` writes `{"error": "..."}` to its cache so the statusline can show why.
- **Per-model rate buckets are auto-detected and capability-ordered** (Fable > Opus >
  Sonnet > Haiku, unknown after). The API returns many codename buckets; only ones with a
  non-null `utilization` render. A `null` `resets_at` means the window is idle → shows `idle`.
- **Caches live in `${TMPDIR}/Codex-statusline-$(id -u)/`** (per-user, not shared `/tmp`).
- **Responsive layout** is driven by `$COLUMNS` (Codex exports it). Three tiers gated
  by `COMPACT_COLS`/`WIDE_COLS`; thresholds are tuned to measured visible line widths.
- **OSC 8 hyperlinks** (`osc_link`) return *literal* escape sequences so they survive the
  header's `printf '%b'`; auto-disabled inside tmux to avoid escape leakage.
- **Config**: `SHOW_*` / threshold vars default via `${VAR:-default}` (env-overridable),
  then the conf file (`~/.Codex/statusline.conf`) takes final precedence.

## Distribution & versioning

Installed three ways: plugin marketplace, `install-remote.sh` (curl one-liner), or
`install.sh` (clone). The plugin's **SessionStart hook runs `scripts/setup.sh`**, which
copies `statusline.sh` + `ccusage-cache.sh` into `~/.Codex/` on every session from
`$CLAUDE_PLUGIN_ROOT` — so the running copy tracks the *installed plugin version*, not your
local edits.

**Releasing requires bumping the version in BOTH `.Codex-plugin/plugin.json` AND
`.Codex-plugin/marketplace.json`** — `/plugin update` reads the advertised version from
`marketplace.json`, so leaving it stale means updates never propagate. Then add a
`CHANGELOG.md` entry and create an annotated `vX.Y.Z` git tag + GitHub release.
