#!/bin/bash
# Tests for the ultracode badge: runs statusline.sh against small transcript
# fixtures (the JSON shapes Claude Code 2.1.261 writes) with a throwaway HOME
# and checks whether the header shows `ultracode` or the plain effort badge.
#   bash scripts/test-ultracode-badge.sh            # tests ./statusline.sh
#   S=/path/to/statusline.sh bash scripts/test-ultracode-badge.sh
S=${S:-$(dirname "$0")/../statusline.sh}
tmp=$(mktemp -d) && [ -n "$tmp" ] && [ -d "$tmp" ] || { echo "mktemp -d failed (TMPDIR=${TMPDIR:-unset}) — aborting"; exit 1; }
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home/.claude" "$tmp/tmp"
esc=$(printf '\033')
pass=0; fail=0

# Fixture lines — the fields statusline.sh reads, nothing else.
enter='{"type":"attachment","attachment":{"type":"ultra_effort_enter","reminderType":"full"}}'
exit_='{"type":"attachment","attachment":{"type":"ultra_effort_exit"}}'
sys()   { printf '{"type":"system","subtype":"local_command","content":"<local-command-stdout>%s</local-command-stdout>"}\n' "$1"; }
usr()   { printf '{"type":"user","message":{"role":"user","content":"<local-command-stdout>%s</local-command-stdout>"}}\n' "$1"; }
decoy() { printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1"; }
effort_uc='Set effort level to ultracode (this session only): xhigh + dynamic workflow orchestration'
effort_xh='Set effort level to xhigh (this session only): Maximum reasoning depth'
effort_auto='Effort level set to auto (this session only)'
effort_capped="Effort 'max' exceeds your organization's limit for Fable 5; set to 'xhigh' instead (this session only): Maximum reasoning depth"
pin_high='CLAUDE_CODE_EFFORT_LEVEL=xhigh overrides this session — clear it and high takes over'
pin_ultracode='CLAUDE_CODE_EFFORT_LEVEL=xhigh overrides effort this session — clear it and ultracode takes over'
model_uc='Set model to `Fable 5` for this session only with `ultracode` effort'
model_xh='Set model to `Fable 5` for this session only with `xhigh` effort'
model_only='Set model to `Opus 5` for this session only'
kept='Kept model as `Fable 5`'
status_line='Current effort level: ultracode (xhigh + dynamic workflow orchestration)'
prose_user='{"type":"user","message":{"role":"user","content":"Why does it say <local-command-stdout>Set effort level to xhigh (this session only): x</local-command-stdout> here?"}}'

# render <settings-ultracode: true|false|absent> <effort-level or ""> <transcript on stdin>
render() {
  case "$1" in true|false) printf '{"ultracode": %s}\n' "$1" ;; *) printf '{}\n' ;; esac > "$tmp/home/.claude/settings.json"
  cat > "$tmp/t.jsonl"
  local eff=""; [ -n "$2" ] && eff=",\"effort\":{\"level\":\"$2\"}"
  printf '{"model":{"display_name":"Fable 5"},"cwd":"%s","transcript_path":"%s","context_window":{"used_percentage":10,"context_window_size":1000000},"cost":{"total_cost_usd":0}%s}' \
    "$tmp" "$tmp/t.jsonl" "$eff" \
  | HOME="$tmp/home" TMPDIR="$tmp/tmp" COLUMNS=200 STATUSLINE_CONF=/dev/null CLAUDE_CONFIG_DIR= \
    SHOW_RATE_LIMITS=false SHOW_CCUSAGE=false SHOW_TOOLS=false SHOW_AGENTS=false \
    SHOW_GIT_AHEAD=false SHOW_LINKS=false SHOW_BURN_RATE=false \
    bash "$S" 2>&1 | sed "s/${esc}\[[0-9;]*m//g"
}
check() {  # check <name> <expect: on|off|xhigh> <settings> <effort> <<< lines
  local out; out=$(render "$3" "$4")
  case "$2" in
    on)    echo "$out" | grep -q 'ultracode' ;;
    off)   ! echo "$out" | grep -q 'ultracode' ;;
    xhigh) echo "$out" | grep -q 'xhigh' ;;
  esac
  if [ $? -eq 0 ]; then pass=$((pass+1)); echo "PASS $1"; else fail=$((fail+1)); echo "FAIL $1"; fi
}

[ -f "$S" ] || { echo "statusline.sh not found at $S"; exit 1; }
out=$(render absent xhigh <<< "$(sys "$kept")"); echo "$out" | grep -q 'Fable 5' || { echo "SETUP BROKEN: script did not render the model name"; exit 1; }

check "enter attachment -> ultracode"                      on    false xhigh <<< "$enter"
check "enter then exit -> plain effort"                    off   true  xhigh <<< "$enter
$exit_"
check "enter then exit -> xhigh still shown"               xhigh true  xhigh <<< "$enter
$exit_"
check "exit then enter -> ultracode (latest wins)"         on    false xhigh <<< "$exit_
$enter"
check "/effort ultracode (system line) -> ultracode"       on    false xhigh <<< "$exit_
$(sys "$effort_uc")"
check "/effort xhigh -> off"                               off   true  xhigh <<< "$enter
$(sys "$effort_xh")"
check "/effort auto -> off"                                off   true  xhigh <<< "$enter
$(sys "$effort_auto")"
check "/effort max capped by org policy -> off"            off   true  xhigh <<< "$enter
$(sys "$effort_capped")"
check "/effort high under env pin -> off"                  off   true  xhigh <<< "$enter
$(sys "$pin_high")"
check "/effort ultracode under env pin (… takes over) -> on" on  false xhigh <<< "$exit_
$(sys "$pin_ultracode")"
check "/model picker ultracode (user line) -> ultracode"   on    false xhigh <<< "$exit_
$(usr "$model_uc")"
check "/model picker xhigh (user line) -> off"             off   true  xhigh <<< "$enter
$(usr "$model_xh")"
check "/model without effort change -> unchanged (on)"     on    false xhigh <<< "$enter
$(sys "$model_only")"
check "'Kept model' -> unchanged (on)"                     on    false xhigh <<< "$enter
$(sys "$kept")"
check "/effort status output -> unchanged (off)"           off   true  xhigh <<< "$exit_
$(sys "$status_line")"
check "assistant text quoting the command -> ignored"      on    false xhigh <<< "$enter
$(decoy "<local-command-stdout>$effort_xh</local-command-stdout>")"
check "assistant text quoting the exit event -> ignored"   on    false xhigh <<< "$enter
$(decoy "ultra_effort_exit")"
check "user prose quoting the command -> ignored"          on    false xhigh <<< "$enter
$prose_user"
check "non-object JSON line does not break the scan"       on    false xhigh <<< "123
$enter"
check "no event, settings true -> ultracode (launch state)" on   true  xhigh <<< "$(sys "$kept")"
check "no event, settings false -> off"                    off   false xhigh <<< "$(sys "$kept")"
check "no event, no settings key -> off"                   off   absent xhigh <<< "$(sys "$kept")"
check "empty transcript, settings true -> ultracode"       on    true  xhigh <<< ""
check "exit event beats settings true"                     off   true  xhigh <<< "$exit_"
check "no effort field on stdin -> never ultracode"        off   true  ""    <<< "$enter"
check "effort high on stdin -> never ultracode"            off   true  high  <<< "$enter"
# only the last 4 MB are scanned: an older event falls back to the launch state
filler=$(printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}' "$(head -c 60000 /dev/zero | tr '\0' x)")
check "event older than the 4 MB window -> launch state (settings true -> on)" on true xhigh <<< "$exit_
$(for i in $(seq 1 72); do printf '%s\n' "$filler"; done)"
check "event inside the 4 MB window still counts (exit -> off)" off true xhigh <<< "$(for i in $(seq 1 72); do printf '%s\n' "$filler"; done)
$exit_"

echo "---- $pass passed, $fail failed"; [ "$fail" -eq 0 ]
