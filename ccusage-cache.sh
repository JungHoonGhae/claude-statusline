#!/bin/bash
# Background cache updater for ccusage token stats
# Runs via statusline, cached for 10 minutes (ccusage is slow ~5s)
# On failure, writes {"error": "..."} so the statusline can show why
# the section is missing instead of silently hiding it.

OS_TYPE="$(uname -s)"
get_mtime() {
  case "$OS_TYPE" in
    Darwin) stat -f %m "$1" 2>/dev/null || echo 0 ;;
    *) stat -c %Y "$1" 2>/dev/null || echo 0 ;;
  esac
}

days_ago() {
  case "$OS_TYPE" in
    Darwin) date -v-"$1"d +%Y-%m-%d ;;
    *) date -d "$1 days ago" +%Y-%m-%d ;;
  esac
}

# Must match CACHE_DIR in statusline.sh
CACHE_DIR="${TMPDIR:-/tmp}/claude-statusline-$(id -u)"
mkdir -p "$CACHE_DIR" 2>/dev/null
CACHE_FILE="$CACHE_DIR/ccusage.json"
CACHE_TTL=600  # 10 minutes

write_error() {
  printf '{"error":"%s"}\n' "$1" > "$CACHE_FILE"
  exit 0
}

# Check if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
  if [ "$cache_age" -lt "$CACHE_TTL" ]; then
    exit 0  # cache is fresh
  fi
fi

command -v npx >/dev/null 2>&1 || write_error "npx not found — install Node.js (or set SHOW_CCUSAGE=false)"
command -v jq >/dev/null 2>&1 || write_error "jq not found"

# Fetch and aggregate: today, yesterday, last 30 days
# ccusage >= 18 renamed --days to --since and .daily[].date to .period,
# and may emit one row per agent — keep both schemas working
data=$(npx ccusage@latest daily --since "$(days_ago 30)" --json 2>/dev/null)
[ -n "$data" ] || write_error "ccusage failed — try: npx ccusage@latest daily --json"

agg=$(echo "$data" | jq --arg today "$(date +%Y-%m-%d)" --arg yest "$(days_ago 1)" '
  def day($rows; $d):
    [$rows[] | select((.period // .date) == $d)]
    | {totalTokens: ([.[].totalTokens] | add // 0), totalCost: ([.[].totalCost] | add // 0)};
  (.daily // []) as $all
  | ([$all[] | select((.agent // "all") == "all")] | if length > 0 then . else $all end) as $rows
  | {
      today: day($rows; $today),
      yesterday: day($rows; $yest),
      last30: {totalTokens: ([$rows[].totalTokens] | add // 0), totalCost: ([$rows[].totalCost] | add // 0)}
    }
' 2>/dev/null)

if [ -n "$agg" ] && echo "$agg" | jq -e '.today' >/dev/null 2>&1; then
  echo "$agg" > "$CACHE_FILE"
else
  write_error "unexpected ccusage output — try: npx ccusage@latest daily --json"
fi
