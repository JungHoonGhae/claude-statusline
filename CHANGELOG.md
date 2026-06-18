# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/), and this project adheres to
[Semantic Versioning](https://semver.org/).

## [1.4.2] — 2026-06-15

### Fixed
- Rate-limit gauges no longer pack their dots together on medium-width terminals.
  The rate-limit lines now compact at their own threshold (~64 cols) instead of
  sharing the header's (~100), and the tight form uses 5 spaced dots — so the
  dots stay legible and evenly spaced at every width.

## [1.4.1] — 2026-06-15

### Added
- **Responsive layout** — three tiers sized to the terminal width via `$COLUMNS`:
  full (≥132 cols) with context bar, token detail, and burn rate; medium (≥100)
  standard header; compact (<100) minimal header plus tightened rate-limit lines.
- `idle` label on unused rate-limit buckets (0% utilization, `resets_at: null`)
  instead of a blank that read as missing data.

### Changed
- Context gauge is now a lighter 5-dot spaced bar (was 10 packed dots).
- Session name in the header is opt-in (`SHOW_SESSION_NAME`, default off).

### Fixed
- `marketplace.json` version was pinned at `1.0.0`, so `/plugin update` never
  saw a newer release — kept in sync with `plugin.json` now.
- Screenshot shows only buckets that really render (Session/Weekly/Sonnet); the
  fictional Fable/Opus lines and the Opus-only `⚡fast` badge were removed.

## [1.4.0] — 2026-06-11

### Added
- Header extras, each toggleable (conf file or env var, conf wins):
  - `SHOW_CONTEXT_BAR` — mini gauge next to ctx %.
  - `SHOW_BURN_RATE` — ~$/hr spend rate (cost ÷ session duration).
  - `SHOW_GIT_AHEAD` — ↑ahead ↓behind vs upstream branch.
  - `SHOW_LINKS` — clickable PR link via OSC 8 (auto-off inside tmux).

## [1.3.0] — 2026-06-11

### Added
- Installers (`install.sh`, `install-remote.sh`) auto-install `jq`/`curl` via the
  detected package manager (brew / apt / dnf / yum / pacman / apk).
- Per-model rate buckets are ordered by capability (Fable > Opus > Sonnet > Haiku),
  with unknown buckets sorted after.
- `scripts/screenshot.sh` — reusable README screenshot generator that renders the
  statusline inside a mock Claude Code UI.

### Fixed
- Every previously-silent failure now surfaces a dim hint (missing `jq`, missing
  `curl`, `npx`/ccusage errors) instead of a blank section.
- Caches moved from shared `/tmp` files to a per-user directory (multi-user
  collision and data-leak fix).

## [1.2.2] — 2026-06-11

### Fixed
- Show a visible `jq not found` hint instead of going silently blank — common in
  Docker containers after a restart drops the in-container `jq`.

## [1.2.1] — 2026-06-11

### Fixed
- ccusage section broke under ccusage v18 (removed `--days`, renamed
  `.daily[].date` → `.period`, optional per-agent rows). The cache script now
  handles both the old and new schemas.

## [1.2.0] — 2026-06-11

### Added
- Auto-detect per-model weekly rate buckets from the OAuth usage API, so new
  models appear without a script update; `null` buckets are hidden, and an
  `Extra` gauge shows when extra-usage credits are enabled.

## [1.1.0] — 2026-06-11

### Added
- Support for the v2.1.x statusline stdin schema: model badges (⚡ fast mode,
  effort level, ✦ thinking), context token detail (e.g. `143.5K/1M`), PR badge
  with review state, and session lines +/-.

### Fixed
- stdin no longer carries `.git`, so branch and dirty state are read from the
  `git` CLI directly (the branch display had silently stopped working).

## [1.0.0]

### Added
- Initial release: pure-bash Claude Code statusline with context %, rate limits,
  tool/agent activity, and daily/monthly token costs. Plugin marketplace support,
  one-liner installer, and Windows (Git Bash / MSYS2 / WSL) support.

[1.4.2]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.4.1...v1.4.2
[1.4.1]: https://github.com/JungHoonGhae/claude-statusline/releases/tag/v1.4.1
[1.4.0]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.2.0...v1.2.2
[1.2.1]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/JungHoonGhae/claude-statusline/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/JungHoonGhae/claude-statusline/releases/tag/v1.0.0
