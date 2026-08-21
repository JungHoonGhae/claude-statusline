#!/usr/bin/env bash
# Cloud Agent install step for claude-statusline.
#
# This project is a pure-bash statusline with no build step and no test
# framework. "Setting up" therefore means: guarantee the runtime dependencies
# the statusline shells out to (jq, curl) are present, confirm the optional
# Node.js/npx tooling used by the ccusage section, and run the repository's
# documented syntax-check gate over every shell script. It is idempotent and
# safe to re-run.
set -euo pipefail

log() { printf '  %s\n' "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

ensure_dep() {
  local cmd=$1 pkg=${2:-$1}
  if command -v "$cmd" >/dev/null 2>&1; then
    log "$cmd present: $(command -v "$cmd")"
    return 0
  fi
  log "$cmd missing — installing $pkg"
  $SUDO apt-get update -qq
  $SUDO apt-get install -y "$pkg"
}

# jq and curl are the only hard runtime dependencies of the statusline.
ensure_dep jq
ensure_dep curl

# Node.js / npx is optional (powers the ccusage token-cost section). Report it
# loudly rather than failing setup when it is absent.
if command -v npx >/dev/null 2>&1; then
  log "node present: $(node --version 2>/dev/null || echo unknown) (npx $(npx --version 2>/dev/null || echo unknown))"
else
  log "node/npx not found — ccusage token-cost section will show an install hint"
fi

# The project's canonical pre-commit check: syntax-check every shell script.
log "running syntax checks (bash -n)"
bash -n statusline.sh ccusage-cache.sh install.sh install-remote.sh scripts/*.sh
log "syntax checks passed"

log "claude-statusline environment ready"
