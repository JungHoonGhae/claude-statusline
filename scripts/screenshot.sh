#!/bin/bash
# Regenerate README screenshot.png from a realistic sample payload.
#
# Renders statusline.sh wrapped in a mock Claude Code UI (banner, input box,
# permission line) so the README image shows where the statusline appears and
# stays easy to refresh whenever a feature is added.
#
# Requirements: jq, charmbracelet/freeze, a Nerd Font (auto-downloaded), python3.
#   brew install charmbracelet/tap/freeze
#
# Usage:
#   scripts/screenshot.sh                 # writes ./screenshot.png
#   SAMPLE=my.json scripts/screenshot.sh  # use a custom stdin payload
#
# To showcase a new feature: edit the SAMPLE / fake-cache heredocs below so the
# payload exercises it, then re-run.

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${OUT:-$REPO_ROOT/screenshot.png}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

command -v jq      >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is required"; exit 1; }
command -v freeze  >/dev/null 2>&1 || { echo "freeze is required: brew install charmbracelet/tap/freeze"; exit 1; }

# A font with full glyph coverage (◐ ✦ ● box-drawing). freeze's default font
# renders some of these as tofu, so fetch a Nerd Font on first run.
FONT="$WORK/font.ttf"
FONT_CACHE="${TMPDIR:-/tmp}/claude-statusline-screenshot-font.ttf"
if [ -f "$FONT_CACHE" ]; then
  cp "$FONT_CACHE" "$FONT"
else
  echo "Downloading a Nerd Font for glyph coverage..."
  curl -fsSL -o "$WORK/nf.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -o -j "$WORK/nf.zip" "JetBrainsMonoNerdFontMono-Regular.ttf" -d "$WORK" >/dev/null
  mv "$WORK/JetBrainsMonoNerdFontMono-Regular.ttf" "$FONT"
  cp "$FONT" "$FONT_CACHE"
fi

# ── Sample payload (edit to exercise new fields) ──────────────────────────────
SAMPLE="${SAMPLE:-$WORK/sample.json}"
if [ ! -f "$SAMPLE" ]; then
cat > "$SAMPLE" <<EOF
{
  "model": {"id": "claude-fable-5[1m]", "display_name": "Fable 5"},
  "cwd": "/Users/junghoon/workspace/projects/oss-qraft",
  "workspace": {"current_dir": "/Users/junghoon/workspace/projects/oss-qraft"},
  "session_name": "refactor-pipeline",
  "transcript_path": "$WORK/transcript.jsonl",
  "version": "2.1.170",
  "fast_mode": true,
  "effort": {"level": "high"},
  "thinking": {"enabled": true},
  "pr": {"number": 42, "review_state": "approved"},
  "cost": {"total_cost_usd": 50.07, "total_duration_ms": 7380000, "total_lines_added": 1036, "total_lines_removed": 49},
  "context_window": {"used_percentage": 14, "context_window_size": 1000000,
    "current_usage": {"input_tokens": 2, "output_tokens": 2448, "cache_creation_input_tokens": 2225, "cache_read_input_tokens": 141280}},
  "rate_limits": {"five_hour": {"used_percentage": 17, "resets_at": 0}, "seven_day": {"used_percentage": 17, "resets_at": 0}}
}
EOF
fi

# Resolve reset epochs relative to now so "Resets in ..." reads naturally.
NOW=$(date +%s)
jq --argjson now "$NOW" '
  .rate_limits.five_hour.resets_at = ($now + 5220)
  | .rate_limits.seven_day.resets_at = ($now + 345600)
' "$SAMPLE" > "$WORK/stdin.json"

# ── Fake caches (per-model buckets + ccusage) ─────────────────────────────────
iso() { python3 -c "import time,sys; print(time.strftime('%Y-%m-%dT%H:%M:%S+00:00', time.gmtime($NOW+int(sys.argv[1]))))" "$1"; }
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline-$(id -u)"
mkdir -p "$CACHE_DIR"
# Back up the user's real caches, restore on exit.
[ -f "$CACHE_DIR/usage.json" ]   && cp "$CACHE_DIR/usage.json"   "$WORK/usage.bak"
[ -f "$CACHE_DIR/ccusage.json" ] && cp "$CACHE_DIR/ccusage.json" "$WORK/ccusage.bak"
restore() {
  [ -f "$WORK/usage.bak" ]   && cp "$WORK/usage.bak"   "$CACHE_DIR/usage.json"   || rm -f "$CACHE_DIR/usage.json"
  [ -f "$WORK/ccusage.bak" ] && cp "$WORK/ccusage.bak" "$CACHE_DIR/ccusage.json" || rm -f "$CACHE_DIR/ccusage.json"
  rm -rf "$WORK"
}
trap restore EXIT

cat > "$CACHE_DIR/usage.json" <<EOF
{
  "five_hour":  {"utilization": 17, "resets_at": "$(iso 5220)"},
  "seven_day":  {"utilization": 17, "resets_at": "$(iso 345600)"},
  "seven_day_fable":  {"utilization": 37, "resets_at": "$(iso 399600)"},
  "seven_day_opus":   {"utilization": 12, "resets_at": "$(iso 399600)"},
  "seven_day_sonnet": {"utilization": 0,  "resets_at": "$(iso 399600)"},
  "extra_usage": {"is_enabled": false}
}
EOF
touch "$CACHE_DIR/usage.json"

cat > "$CACHE_DIR/ccusage.json" <<'EOF'
{
  "today":     {"totalCost": 227.00, "totalTokens": 264500000},
  "yesterday": {"totalCost": 101.77, "totalTokens": 111700000},
  "last30":    {"totalCost": 3449.66, "totalTokens": 3900000000}
}
EOF
touch "$CACHE_DIR/ccusage.json"

# Fake transcript: completed tool counts + one running tool + one running agent.
python3 - "$WORK/transcript.jsonl" <<'PY'
import json, sys
out = []
def pair(i, name, inp):
    tid = f"t{i}"
    out.append(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","id":tid,"name":name,"input":inp}]}}))
    out.append(json.dumps({"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":tid}]}}))
i = 0
for name, n, inp in [("Bash",40,{"command":"npm test"}),("Edit",19,{"file_path":"/x/app.ts"}),
                     ("Read",12,{"file_path":"/x/app.ts"}),("Write",11,{"file_path":"/x/new.ts"}),("Grep",2,{"pattern":"TODO"})]:
    for _ in range(n):
        pair(i, name, inp); i += 1
out.append(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","id":"run1","name":"Bash","input":{"command":"npm run build"}}]}}))
out.append(json.dumps({"type":"assistant","message":{"content":[{"type":"tool_use","id":"ag1","name":"Agent","input":{"subagent_type":"Explore","description":"Explore current Qraft codebase"}}]}}))
open(sys.argv[1],"w").write("\n".join(out) + "\n")
PY

# ── Render statusline, wrap in mock Claude Code UI ────────────────────────────
bash "$REPO_ROOT/statusline.sh" < "$WORK/stdin.json" > "$WORK/statusline.ansi"

# Substitute glyphs the render font lacks (terminal shows the originals fine).
sed 's/◐/◉/g; s/✦/✶/g' "$WORK/statusline.ansi" > "$WORK/statusline.sub.ansi"

python3 - "$WORK/statusline.sub.ansi" "$WORK/ui.ansi" <<'PY'
import re, sys
sl = open(sys.argv[1]).read().rstrip('\n').split('\n')
strip = lambda s: re.sub(r'\x1b\[[0-9;]*m', '', s)
w = max(len(strip(l)) for l in sl) + 2
O, B, D, R = '\033[38;5;208m', '\033[1;37m', '\033[2m', '\033[0m'
L = []
L += ['']
L += [f' {O} ▐▛███▜▌{R}   {B}Claude Code v2.1.170{R}']
L += [f' {O}▝▜█████▛▘{R}  Fable 5 · Claude Max']
L += [f' {O}  ▘▘ ▝▝{R}    {D}~/workspace/projects/oss-qraft{R}']
L += ['']
L += [f' {D}╭{"─"*(w-2)}╮{R}']
L += [f' {D}│{R} {D}>{R} {" "*(w-6)}{D}│{R}']
L += [f' {D}╰{"─"*(w-2)}╯{R}']
L += sl
L += [f'  {O}❯❯ bypass permissions on{R}{D} (shift+tab to cycle){R}']
L += ['']
open(sys.argv[2], 'w').write('\n'.join(L) + '\n')
PY

freeze "$WORK/ui.ansi" --language ansi --output "$OUT" \
  --window --padding 16,24,16,24 --background "#171717" --font.size 13 --font.file "$FONT"

echo "Wrote $OUT"
