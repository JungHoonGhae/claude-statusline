#!/bin/bash
# Token cost aggregator for the statusline — pure bash + jq, no Node.js.
#
# Reads Claude Code transcripts (~/.claude/projects/**/*.jsonl) directly and
# prices them per-model. Pricing comes from LiteLLM's public database — the same
# source ccusage uses — fetched with curl and cached for a day; when the fetch is
# unavailable it falls back to a built-in table. Output is cached for 10 minutes
# and written as {"today":..,"yesterday":..,"last30":..} (or {"error":..}) so the
# statusline can render or explain the section.
#
# Dependencies: jq only. curl is used opportunistically to keep prices current —
# without it (or offline) the built-in table is used, so the section still works.

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
PRICE_FILE="$CACHE_DIR/litellm-prices.json"
CACHE_TTL=600         # 10 minutes for a successful result
ERROR_CACHE_TTL=60    # 1 minute for an error result
PRICE_TTL=86400       # refresh the LiteLLM price table once a day
PROJECTS_DIR="$HOME/.claude/projects"
LITELLM_URL="https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"

write_error() {
  printf '{"error":"%s"}\n' "$1" > "$CACHE_FILE"
  exit 0
}

# Check if cache is fresh. Error results expire faster so that fixing the
# underlying cause recovers on the next refresh instead of showing a stale
# error for the full 10 minutes.
if [ -f "$CACHE_FILE" ]; then
  cache_age=$(( $(date +%s) - $(get_mtime "$CACHE_FILE") ))
  ttl=$CACHE_TTL
  if grep -q '"error"' "$CACHE_FILE" 2>/dev/null; then
    ttl=$ERROR_CACHE_TTL
  fi
  if [ "$cache_age" -lt "$ttl" ]; then
    exit 0  # cache is fresh
  fi
fi

command -v jq >/dev/null 2>&1 || write_error "jq not found"
[ -d "$PROJECTS_DIR" ] || write_error "no usage data at ~/.claude/projects"

# Refresh the LiteLLM price table (curl) when it's older than a day. On any
# failure keep the previous copy; aggregation falls back to the built-in table
# for models the file doesn't cover.
if command -v curl >/dev/null 2>&1; then
  price_age=$PRICE_TTL
  [ -f "$PRICE_FILE" ] && price_age=$(( $(date +%s) - $(get_mtime "$PRICE_FILE") ))
  if [ "$price_age" -ge "$PRICE_TTL" ]; then
    tmp="$PRICE_FILE.tmp.$$"
    if curl -fsSL --max-time 10 "$LITELLM_URL" -o "$tmp" 2>/dev/null && jq -e . "$tmp" >/dev/null 2>&1; then
      mv -f "$tmp" "$PRICE_FILE"
    else
      rm -f "$tmp"
    fi
  fi
fi
[ -f "$PRICE_FILE" ] || echo '{}' > "$PRICE_FILE"

today=$(date +%Y-%m-%d)
yest=$(days_ago 1)
d30=$(days_ago 30)

# Aggregate token cost per local day across all transcripts, de-duplicating
# repeated API responses (the same message id + request id can reappear in
# resumed sessions). Pricing: LiteLLM per-token rates keyed by the exact model
# id, with a built-in per-family fallback ($/1M ÷ 1e6) for anything LiteLLM lacks.
agg=$(find "$PROJECTS_DIR" -name '*.jsonl' -type f -mtime -31 -print0 2>/dev/null \
  | xargs -0 cat 2>/dev/null \
  | jq -n --slurpfile prices "$PRICE_FILE" \
        --arg today "$today" --arg yest "$yest" --arg d30 "$d30" '
    ($prices[0] // {}) as $ll
    | def fallback_price($m):
        if   ($m|test("haiku"))        then {i:1e-6, o:5e-6,  r:1e-7, w5:1.25e-6, w1:2e-6}
        elif ($m|test("sonnet"))       then {i:3e-6, o:15e-6, r:3e-7, w5:3.75e-6, w1:6e-6}
        elif ($m|test("fable|mythos")) then {i:1e-5, o:5e-5,  r:1e-6, w5:1.25e-5, w1:2e-5}
        else                                {i:5e-6, o:25e-6, r:5e-7, w5:6.25e-6, w1:1e-5} end;
      def price($m):
        $ll[$m] as $p
        | if ($p != null) and ($p.input_cost_per_token != null)
          then { i:  $p.input_cost_per_token,
                 o: ($p.output_cost_per_token // 0),
                 r: ($p.cache_read_input_token_cost // 0),
                 w5:($p.cache_creation_input_token_cost // 0),
                 w1:($p.cache_creation_input_token_cost_above_1hr
                     // (($p.cache_creation_input_token_cost // 0) * 1.6)) }
          else fallback_price($m) end;
      reduce inputs as $l ({seen:{}, days:{}};
        if ($l.type == "assistant") and ($l.message.usage != null)
           and ((($l.message.model // "") | test("<synthetic>")) | not)
        then
          (($l.message.id // "") + "|" + ($l.requestId // "")) as $key
          | if .seen[$key] then .
            else
              .seen[$key] = true
              | ($l.timestamp | sub("\\.[0-9]+Z$";"Z") | fromdateiso8601 | strflocaltime("%Y-%m-%d")) as $date
              | price($l.message.model // "") as $p
              | $l.message.usage as $u
              | ($u.input_tokens // 0) as $in
              | ($u.output_tokens // 0) as $out
              | ($u.cache_read_input_tokens // 0) as $cr
              | ($u.cache_creation.ephemeral_5m_input_tokens
                  // ($u.cache_creation_input_tokens // 0)) as $w5
              | ($u.cache_creation.ephemeral_1h_input_tokens // 0) as $w1
              | ($in*$p.i + $out*$p.o + $cr*$p.r + $w5*$p.w5 + $w1*$p.w1) as $cost
              | ($in + $out + $cr + $w5 + $w1) as $tok
              | .days[$date].cost   = ((.days[$date].cost   // 0) + $cost)
              | .days[$date].tokens = ((.days[$date].tokens // 0) + $tok)
            end
        else . end
      )
      | .days as $d
      | { today:     {totalTokens: ($d[$today].tokens // 0), totalCost: ($d[$today].cost // 0)},
          yesterday: {totalTokens: ($d[$yest].tokens  // 0), totalCost: ($d[$yest].cost  // 0)},
          last30:    {totalTokens: ([$d|to_entries[]|select(.key>=$d30)|.value.tokens]|add // 0),
                      totalCost:   ([$d|to_entries[]|select(.key>=$d30)|.value.cost]|add   // 0)} }
  ' 2>/dev/null)

if [ -n "$agg" ] && echo "$agg" | jq -e '.today' >/dev/null 2>&1; then
  echo "$agg" > "$CACHE_FILE"
else
  write_error "usage aggregation failed"
fi
