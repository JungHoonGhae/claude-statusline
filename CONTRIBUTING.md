# Contributing to claude-statusline

Thanks for your interest in improving claude-statusline! This is a small, pure-bash
project, so contributing is straightforward.

## Getting started

1. Fork and clone the repo.
2. Make your changes to `statusline.sh`, `ccusage-cache.sh`, or the installers.
3. Test locally (see below).
4. Open a pull request.

## Testing your changes

The statusline reads a JSON object on stdin and prints the rendered output. You can
test it without restarting Claude Code by piping a sample payload:

```bash
echo '{
  "model": {"id": "claude-fable-5", "display_name": "Fable 5"},
  "cwd": "'"$PWD"'",
  "context_window": {"used_percentage": 14, "context_window_size": 1000000,
    "current_usage": {"input_tokens": 2, "cache_read_input_tokens": 141280, "cache_creation_input_tokens": 2225}},
  "cost": {"total_cost_usd": 24.32, "total_duration_ms": 2563618, "total_lines_added": 1036, "total_lines_removed": 49}
}' | bash statusline.sh
```

Always run a syntax check before committing:

```bash
bash -n statusline.sh && bash -n ccusage-cache.sh && bash -n install.sh && bash -n install-remote.sh
```

## Refreshing the README screenshot

When you add a section or badge, regenerate the README image so it stays current:

```bash
brew install charmbracelet/tap/freeze   # one-time
scripts/screenshot.sh                    # writes ./screenshot.png
```

The script renders `statusline.sh` against a sample payload wrapped in a mock
Claude Code UI (banner, input box, permission line). To showcase a new field,
edit the `SAMPLE` payload and fake-cache heredocs inside `scripts/screenshot.sh`.
It backs up and restores your real `~/.claude` caches automatically.

## Guidelines

- **Keep it pure bash.** The whole point of this project is zero runtime beyond
  `jq`/`curl`. Don't add Node.js, Python, or other interpreters to the hot path.
- **Fail loudly, not silently.** If a dependency is missing or an external command
  fails, show a dim hint explaining why rather than hiding a section.
- **Stay POSIX-friendly.** Target bash 3.2 (the macOS default) — avoid `${var^^}`,
  associative arrays, and other bash 4+ features.
- **Support macOS, Linux, and Windows (Git Bash/WSL).** Use the existing
  `OS_TYPE` helpers for anything platform-specific (`stat`, `date`, keychain).
- **Match the surrounding style** — comment density, section banners, and naming.

## Reporting bugs

Open an issue using the bug report template and include your OS, Claude Code
version, and the output of:

```bash
echo '{}' | bash ~/.claude/statusline-command.sh
```

## License

By contributing, you agree that your contributions will be licensed under the
[MIT License](LICENSE).
