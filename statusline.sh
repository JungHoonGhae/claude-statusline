#!/bin/bash
# Claude Code Custom Statusline
# https://github.com/junghoon-io/claude-statusline
#
# A rich statusline for Claude Code that shows context usage, rate limits,
# tool/agent activity, and daily token costs — all in pure bash.
#
# Dependencies: jq, curl
# Optional: ccusage (npm) for token cost tracking

# ── Platform Detection ────────────────────────────────────────────────────────
OS_TYPE="$(uname -s)"

get_mtime() {
  if [ "$OS_TYPE" = "Darwin" ]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

parse_iso_to_epoch() {
  local ts=$1
  if [ "$OS_TYPE" = "Darwin" ]; then
    TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$ts" "+%s" 2>/dev/null
  else
    TZ=UTC date -d "${ts}" "+%s" 2>/dev/null
  fi
}

get_oauth_token() {
  if [ "$OS_TYPE" = "Darwin" ]; then
    security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
      | jq -r '.claudeAiOauth.accessToken // empty'
  else
    # Linux: try credentials file, then secret-tool (GNOME Keyring)
    local cred_file="$HOME/.claude/.credentials.json"
    if [ -f "$cred_file" ]; then
      jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null
    elif command -v secret-tool >/dev/null 2>&1; then
      secret-tool lookup service "Claude Code-credentials" 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
    fi
  fi
}

# ── Configuration ─────────────────────────────────────────────────────────────
SHOW_RATE_LIMITS=true
SHOW_TOOLS=true
SHOW_AGENTS=true
SHOW_CCUSAGE=true
CONTEXT_WARN_PCT=30
CONTEXT_CRIT_PCT=70
DAILY_BUDGET=0

STATUSLINE_CONF="${STATUSLINE_CONF:-$HOME/.claude/statusline.conf}"
if [ -f "$STATUSLINE_CONF" ]; then
  while IFS='=' read -r key val; do
    key=$(echo "$key" | tr -d '[:space:]')
    val=$(echo "$val" | tr -d '[:space:]')
    case "$key" in
      SHOW_RATE_LIMITS|SHOW_TOOLS|SHOW_AGENTS|SHOW_CCUSAGE) eval "$key=$val" ;;
      CONTEXT_WARN_PCT|CONTEXT_CRIT_PCT|DAILY_BUDGET) eval "$key=$val" ;;
    esac
  done < <(grep -v '^\s*#' "$STATUSLINE_CONF" | grep -v '^\s*$')
fi

# ── Parse stdin from Claude Code ──────────────────────────────────────────────
input=$(cat)

eval "$(jq -r '
  @sh "model=\(.model.display_name // "Unknown")",
  @sh "used=\(.context_window.used_percentage // 0 | floor)",
  @sh "cwd=\(.workspace.current_dir // .cwd // "")",
  @sh "cost=\(.cost.total_cost_usd // 0)",
  @sh "duration_ms=\(.cost.total_duration_ms // 0)",
  @sh "git_branch=\(.git.branch // "")",
  @sh "git_dirty=\(.git.dirty // false)",
  @sh "worktree=\(.worktree.name // "")",
  @sh "transcript_path=\(.transcript_path // "")",
  @sh "stdin_5h_used=\(.rate_limits.five_hour.used_percentage // "")",
  @sh "stdin_5h_reset=\(.rate_limits.five_hour.resets_at // "")",
  @sh "stdin_7d_used=\(.rate_limits.seven_day.used_percentage // "")",
  @sh "stdin_7d_reset=\(.rate_limits.seven_day.resets_at // "")"
' <<< "$input")"

# ── Project & Branch ──────────────────────────────────────────────────────────
project=$(basename "$cwd" 2>/dev/null)

dirty_mark=""
if [ "$git_dirty" = "true" ]; then
  dirty_mark="\033[31m*\033[0m"
fi

location_str=""
if [ -n "$worktree" ]; then
  location_str=" \033[35m⎇ ${worktree}\033[0m${dirty_mark}"
elif [ -n "$git_branch" ]; then
  location_str=" \033[35m(${git_branch})\033[0m${dirty_mark}"
fi

# ── Format Duration ───────────────────────────────────────────────────────────
if [ "$duration_ms" -gt 0 ] 2>/dev/null; then
  total_sec=$((duration_ms / 1000))
  hours=$((total_sec / 3600))
  mins=$(( (total_sec % 3600) / 60 ))
  if [ "$hours" -gt 0 ]; then
    duration_str="${hours}h ${mins}m"
  elif [ "$mins" -gt 0 ]; then
    duration_str="${mins}m"
  else
    duration_str="${total_sec}s"
  fi
else
  duration_str="0s"
fi

# ── Format Cost ───────────────────────────────────────────────────────────────
if [ "$cost" != "0" ] && [ -n "$cost" ]; then
  cost_str=$(printf '$%.2f' "$cost")
else
  cost_str='$0.00'
fi

# ── Color Helpers ─────────────────────────────────────────────────────────────

ctx_color() {
  local pct=$1
  if [ "$pct" -lt "$CONTEXT_WARN_PCT" ]; then
    printf "\033[32m"
  elif [ "$pct" -lt "$CONTEXT_CRIT_PCT" ]; then
    printf "\033[33m"
  else
    printf "\033[31m"
  fi
}

make_bar() {
  local pct=$1
  local filled=$((pct / 10))
  [ "$filled" -gt 10 ] && filled=10

  local color
  if [ "$pct" -gt 50 ]; then
    color="\033[32m"
  elif [ "$pct" -gt 20 ]; then
    color="\033[33m"
  else
    color="\033[31m"
  fi

  local bar="" i=0
  while [ "$i" -lt 10 ]; do
    [ "$i" -gt 0 ] && bar="${bar} "
    if [ "$i" -lt "$filled" ]; then
      bar="${bar}${color}●\033[0m"
    else
      bar="${bar}\033[2m○\033[0m"
    fi
    i=$((i + 1))
  done
  printf '%b' "$bar"
}

status_dot() {
  local pct=$1
  if [ "$pct" -gt 50 ]; then
    printf "\033[32m●\033[0m"
  elif [ "$pct" -gt 20 ]; then
    printf "\033[33m●\033[0m"
  else
    printf "\033[31m●\033[0m"
  fi
}

# ── Rate Limit Helpers ────────────────────────────────────────────────────────

format_remaining_epoch() {
  local reset_epoch=$1
  if [ -z "$reset_epoch" ] || [ "$reset_epoch" = "" ]; then
    echo ""
    return
  fi
  if echo "$reset_epoch" | grep -qE '^[0-9]+\.?[0-9]*$'; then
    reset_epoch=${reset_epoch%%.*}
  else
    local utc_ts=${reset_epoch%%+*}
    utc_ts=${utc_ts%%.*}
    reset_epoch=$(parse_iso_to_epoch "$utc_ts")
  fi
  local now_epoch remaining rd rh rm
  now_epoch=$(date +%s)
  if [ -n "$reset_epoch" ] && [ "$reset_epoch" -gt "$now_epoch" ] 2>/dev/null; then
    remaining=$(( reset_epoch - now_epoch ))
    rd=$((remaining / 86400))
    rh=$(( (remaining % 86400) / 3600 ))
    rm=$(( (remaining % 3600) / 60 ))
    if [ "$rd" -gt 0 ]; then
      echo "Resets in ${rd}d ${rh}h"
    elif [ "$rh" -gt 0 ]; then
      echo "Resets in ${rh}h ${rm}m"
    else
      echo "Resets in ${rm}m"
    fi
  else
    echo "Resetting"
  fi
}

print_limit_line() {
  local label=$1 used_val=$2 reset_val=$3
  if [ -n "$used_val" ]; then
    local left=$((100 - used_val))
    printf "  \033[2m%-7s\033[0m %b %s  \033[36m%s%% left\033[0m  \033[2m%s\033[0m\n" \
      "$label" "$(status_dot "$left")" "$(make_bar "$left")" "$left" "$(format_remaining_epoch "$reset_val")"
  fi
}

fmt_tokens() {
  local t=$1
  if [ "$t" -ge 1000000000 ] 2>/dev/null; then
    printf "%d.%dB" $((t / 1000000000)) $(( (t % 1000000000) / 100000000 ))
  elif [ "$t" -ge 1000000 ] 2>/dev/null; then
    printf "%d.%dM" $((t / 1000000)) $(( (t % 1000000) / 100000 ))
  elif [ "$t" -ge 1000 ] 2>/dev/null; then
    printf "%d.%dK" $((t / 1000)) $(( (t % 1000) / 100 ))
  else
    printf "%d" "$t"
  fi
}

# ── Rate Limits: stdin first, API fallback ────────────────────────────────────

# Try stdin rate_limits first (Claude Code v2.1.6+)
if [ -n "$stdin_5h_used" ] && [ "$stdin_5h_used" != "null" ]; then
  five_hour_used=$(printf '%.0f' "$stdin_5h_used" 2>/dev/null || echo 0)
  five_hour_reset="$stdin_5h_reset"
else
  five_hour_used=""
fi

if [ -n "$stdin_7d_used" ] && [ "$stdin_7d_used" != "null" ]; then
  seven_day_used=$(printf '%.0f' "$stdin_7d_used" 2>/dev/null || echo 0)
  seven_day_reset="$stdin_7d_reset"
else
  seven_day_used=""
fi

# API fallback: model-specific limits (Opus/Sonnet) + Session/Weekly if stdin missing
opus_used=""; opus_reset=""
sonnet_used=""; sonnet_reset=""

if [ "$SHOW_RATE_LIMITS" = "true" ]; then
  CACHE_FILE="/tmp/.claude-usage-cache.json"
  CACHE_TTL=120

  fetch_usage() {
    local TOKEN
    TOKEN=$(get_oauth_token)
    if [ -n "$TOKEN" ]; then
      curl -s --max-time 3 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $TOKEN" \
        -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null
    fi
  }

  need_refresh=1
  if [ -f "$CACHE_FILE" ]; then
    cache_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
    if [ "$cache_age" -lt "$CACHE_TTL" ]; then
      need_refresh=0
    fi
  fi

  if [ "$need_refresh" -eq 1 ]; then
    usage_data=$(fetch_usage)
    if [ -n "$usage_data" ] && echo "$usage_data" | jq -e '.five_hour' >/dev/null 2>&1; then
      echo "$usage_data" > "$CACHE_FILE"
    fi
  fi

  if [ -s "$CACHE_FILE" ]; then
    eval "$(jq -r '
      @sh "api_5h_used=\(.five_hour.utilization // "" | if . != "" then (. | floor | tostring) else "" end)",
      @sh "api_5h_reset=\(.five_hour.resets_at // "")",
      @sh "api_7d_used=\(.seven_day.utilization // "" | if . != "" then (. | floor | tostring) else "" end)",
      @sh "api_7d_reset=\(.seven_day.resets_at // "")",
      @sh "opus_used=\(if .seven_day_opus.utilization then (.seven_day_opus.utilization | floor | tostring) else "" end)",
      @sh "opus_reset=\(.seven_day_opus.resets_at // "")",
      @sh "sonnet_used=\(if .seven_day_sonnet.utilization then (.seven_day_sonnet.utilization | floor | tostring) else "" end)",
      @sh "sonnet_reset=\(.seven_day_sonnet.resets_at // "")"
    ' "$CACHE_FILE")"

    [ -z "$five_hour_used" ] && five_hour_used="$api_5h_used" && five_hour_reset="$api_5h_reset"
    [ -z "$seven_day_used" ] && seven_day_used="$api_7d_used" && seven_day_reset="$api_7d_reset"
  fi
fi

ctx_c=$(ctx_color "$used")

# ── ccusage Token Stats (cached 10 min, background refresh) ──────────────────
has_ccusage=0

if [ "$SHOW_CCUSAGE" = "true" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  CCUSAGE_CACHE="/tmp/.claude-ccusage-cache.json"
  CCUSAGE_TTL=600

  if [ -f "$CCUSAGE_CACHE" ]; then
    cc_age=$(( $(date +%s) - $(get_mtime "$CCUSAGE_CACHE") ))
    if [ "$cc_age" -ge "$CCUSAGE_TTL" ]; then
      bash "$SCRIPT_DIR/ccusage-cache.sh" &>/dev/null &
    fi
  else
    bash "$SCRIPT_DIR/ccusage-cache.sh" &>/dev/null &
  fi

  if [ -s "$CCUSAGE_CACHE" ]; then
    eval "$(jq -r '
      @sh "today_cost=\(.today.totalCost // 0)",
      @sh "today_tokens=\(.today.totalTokens // 0 | floor)",
      @sh "yest_cost=\(.yesterday.totalCost // 0)",
      @sh "yest_tokens=\(.yesterday.totalTokens // 0 | floor)",
      @sh "m30_cost=\(.last30.totalCost // 0)",
      @sh "m30_tokens=\(.last30.totalTokens // 0 | floor)"
    ' "$CCUSAGE_CACHE")"

    today_cost_str=$(printf '$%.2f' "$today_cost")
    today_tok_str=$(fmt_tokens "$today_tokens")
    yest_cost_str=$(printf '$%.2f' "$yest_cost")
    yest_tok_str=$(fmt_tokens "$yest_tokens")
    m30_cost_str=$(printf '$%.2f' "$m30_cost")
    m30_tok_str=$(fmt_tokens "$m30_tokens")
    has_ccusage=1
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# OUTPUT
# ══════════════════════════════════════════════════════════════════════════════
echo ""

# Line 1: Model | ctx % (colored) | project (branch*) | cost · duration
printf "  \033[1;37m%s\033[0m \033[2m│\033[0m %bctx %s%%\033[0m \033[2m│\033[0m \033[33m%s\033[0m%b \033[2m│\033[0m \033[2m%s · %s\033[0m\n" \
  "$model" "$ctx_c" "$used" "$project" "$location_str" "$cost_str" "$duration_str"

# Compaction warning
if [ "$used" -ge "$CONTEXT_CRIT_PCT" ]; then
  printf "  \033[1;31m⚠ Context %s%% — compaction imminent\033[0m\n" "$used"
fi

# Rate limit lines
if [ "$SHOW_RATE_LIMITS" = "true" ]; then
  print_limit_line "Session" "$five_hour_used" "$five_hour_reset"
  print_limit_line "Weekly"  "$seven_day_used" "$seven_day_reset"
  print_limit_line "Opus"    "$opus_used"      "$opus_reset"
  print_limit_line "Sonnet"  "$sonnet_used"    "$sonnet_reset"
fi

# Tool / Agent Activity (from transcript)
if [ "$SHOW_TOOLS" = "true" ] || [ "$SHOW_AGENTS" = "true" ]; then
  if [ -n "$transcript_path" ] && [ -s "$transcript_path" ]; then
    transcript_data=$(tail -500 "$transcript_path" | jq -c -s '
      [.[] |
        if .type == "assistant" and (.message.content | type) == "array" then
          (.message.content)[] | select(.type == "tool_use") |
          {action: "use", id: .id, name: .name, target: (
            if .name == "Read" or .name == "Write" or .name == "Edit" then (.input.file_path // .input.path // "" | split("/") | .[-1:] | join(""))
            elif .name == "Glob" or .name == "Grep" then (.input.pattern // "")
            elif .name == "Bash" then (.input.command // "" | .[0:30])
            elif .name == "Agent" then (.input.description // .input.subagent_type // "")
            else ""
            end
          ), subagent_type: (.input.subagent_type // ""), agent_desc: (.input.description // "")}
        elif .type == "user" and (.message.content | type) == "array" then
          (.message.content)[] | select(.type == "tool_result") |
          {action: "result", id: .tool_use_id, is_error: (.is_error // false)}
        else empty
        end
      ] |
      (reduce .[] as $item (
        {tools: {}, agents: {}, completed: {}};
        if $item.action == "use" then
          if $item.name == "Agent" then
            .agents[$item.id] = {type: $item.subagent_type, desc: $item.agent_desc, status: "running"}
          elif $item.name != "TodoWrite" and $item.name != "TaskCreate" and $item.name != "TaskUpdate" then
            .tools[$item.id] = {name: $item.name, target: $item.target, status: "running"}
          else .
          end
        elif $item.action == "result" then
          if .agents[$item.id] then
            .agents[$item.id].status = "done"
          elif .tools[$item.id] then
            .tools[$item.id] as $t |
            .tools[$item.id].status = "done" |
            .completed[$t.name] = ((.completed[$t.name] // 0) + 1)
          else .
          end
        else .
        end
      )) |
      {
        running_tools: [.tools | to_entries[] | select(.value.status == "running") | {name: .value.name, target: .value.target}] | .[-3:],
        completed: .completed,
        running_agents: [.agents | to_entries[] | select(.value.status == "running") | {type: .value.type, desc: .value.desc}] | .[-3:],
        done_agents: [.agents | to_entries[] | select(.value.status != "running")] | length
      }
    ' 2>/dev/null)

    if [ -n "$transcript_data" ] && [ "$transcript_data" != "null" ]; then
      IFS=$'\x1e' read -r running_tools completed_tools running_agents done_agent_count <<< "$(
        jq -r '[
          (.running_tools | if length > 0 then [.[] | "◐ \(.name)" + (if .target != "" then ":\(.target)" else "" end)] | join("  ") else "" end),
          (.completed | to_entries | sort_by(-.value) | if length > 0 then [.[:5][] | "✓ \(.key)×\(.value)"] | join("  ") else "" end),
          (.running_agents | if length > 0 then [.[] | "◐ \(.type)" + (if .desc != "" then " \(.desc)" else "" end)] | join("  ") else "" end),
          (.done_agents | tostring)
        ] | join("\u001e")' <<< "$transcript_data"
      )"

      # Tools line
      if [ "$SHOW_TOOLS" = "true" ]; then
        if [ -n "$running_tools" ] || [ -n "$completed_tools" ]; then
          tool_line="  "
          if [ -n "$running_tools" ]; then
            tool_line="${tool_line}\033[33m${running_tools}\033[0m"
            [ -n "$completed_tools" ] && tool_line="${tool_line}  \033[2m${completed_tools}\033[0m"
          else
            tool_line="${tool_line}\033[2m${completed_tools}\033[0m"
          fi
          printf '%b\n' "$tool_line"
        fi
      fi

      # Agents line
      if [ "$SHOW_AGENTS" = "true" ]; then
        if [ -n "$running_agents" ]; then
          agent_line="  \033[35m${running_agents}\033[0m"
          [ "$done_agent_count" -gt 0 ] 2>/dev/null && agent_line="${agent_line}  \033[2m(${done_agent_count} done)\033[0m"
          printf '%b\n' "$agent_line"
        elif [ "$done_agent_count" -gt 0 ] 2>/dev/null; then
          printf '  \033[2m✓ %s agents done\033[0m\n' "$done_agent_count"
        fi
      fi
    fi
  fi
fi

# Token Usage Stats (ccusage)
if [ "$SHOW_CCUSAGE" = "true" ] && [ "$has_ccusage" -eq 1 ]; then
  printf "  \033[2m─────────────────────────────────────────────\033[0m\n"
  printf "  \033[2mToday       \033[0m%20s\033[2m · %s tokens\033[0m\n" "$today_cost_str" "$today_tok_str"
  printf "  \033[2mYesterday   \033[0m%20s\033[2m · %s tokens\033[0m\n" "$yest_cost_str" "$yest_tok_str"
  printf "  \033[2mLast 30 Days\033[0m%20s\033[2m · %s tokens\033[0m\n" "$m30_cost_str" "$m30_tok_str"

  # Daily budget warning
  if [ "$DAILY_BUDGET" -gt 0 ] 2>/dev/null; then
    today_cost_int=${today_cost%%.*}
    [ -z "$today_cost_int" ] && today_cost_int=0
    if [ "$today_cost_int" -ge "$DAILY_BUDGET" ]; then
      printf "  \033[1;31m⚠ Budget: %s / \$%s daily limit exceeded\033[0m\n" "$today_cost_str" "$DAILY_BUDGET"
    fi
  fi
fi

echo ""
