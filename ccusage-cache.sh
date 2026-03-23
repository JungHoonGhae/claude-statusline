#!/bin/bash
# Background cache updater for ccusage token stats
# Runs via statusline, cached for 10 minutes (ccusage is slow ~5s)

OS_TYPE="$(uname -s)"
get_mtime() {
  if [ "$OS_TYPE" = "Darwin" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
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
data=$(npx ccusage@latest daily --days 30 --json 2>/dev/null)

if [ -n "$data" ]; then
  echo "$data" | jq '{
    today: (.daily | map(select(.date == (now | strftime("%Y-%m-%d")))) | .[0] // {totalTokens: 0, totalCost: 0}),
    yesterday: (.daily | map(select(.date == ((now - 86400) | strftime("%Y-%m-%d")))) | .[0] // {totalTokens: 0, totalCost: 0}),
    last30: {totalTokens: ([.daily[].totalTokens] | add // 0), totalCost: ([.daily[].totalCost] | add // 0)}
  }' > "$CACHE_FILE" 2>/dev/null
fi
