#!/bin/bash
# Background cache updater for ccusage token stats
# Runs via statusline, cached for 10 minutes (ccusage is slow ~5s)

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

CACHE_FILE="/tmp/.claude-ccusage-cache.json"
CACHE_TTL=600  # 10 minutes

# Check if cache is fresh
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
  if [ "$cache_age" -lt "$CACHE_TTL" ]; then
    exit 0  # cache is fresh
  fi
fi

# Fetch and aggregate: today, yesterday, last 30 days
# ccusage >= 18 renamed --days to --since and .daily[].date to .period,
# and may emit one row per agent — keep both schemas working
data=$(npx ccusage@latest daily --since "$(days_ago 30)" --json 2>/dev/null)

if [ -n "$data" ]; then
  echo "$data" | jq --arg today "$(date +%Y-%m-%d)" --arg yest "$(days_ago 1)" '
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
  ' > "$CACHE_FILE" 2>/dev/null
fi
