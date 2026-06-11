#!/bin/bash
# Claude Statusline — Remote One-Liner Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/JungHoonGhae/claude-statusline/main/install-remote.sh | bash

set -e

REPO="JungHoonGhae/claude-statusline"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CONF_FILE="$CLAUDE_DIR/statusline.conf"

echo ""
echo "  Claude Code Custom Statusline — Installer"
echo "  ─────────────────────────────────────────"
echo ""

# ── Dependencies (auto-install where possible) ────────────────────────────────
SUDO=""
[ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

install_pkg() {
  local pkg=$1
  if command -v brew >/dev/null 2>&1; then brew install "$pkg"
  elif command -v apt-get >/dev/null 2>&1; then $SUDO apt-get update -qq && $SUDO apt-get install -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then $SUDO dnf install -y "$pkg"
  elif command -v yum >/dev/null 2>&1; then $SUDO yum install -y "$pkg"
  elif command -v pacman >/dev/null 2>&1; then $SUDO pacman -S --noconfirm "$pkg"
  elif command -v apk >/dev/null 2>&1; then $SUDO apk add --no-cache "$pkg"
  else return 1
  fi
}

ensure_dep() {
  local cmd=$1 pkg=${2:-$1}
  command -v "$cmd" >/dev/null 2>&1 && return 0
  echo "  $cmd not found — installing $pkg..."
  if install_pkg "$pkg" >/dev/null 2>&1 && command -v "$cmd" >/dev/null 2>&1; then
    echo "  Installed $pkg"
    return 0
  fi
  echo "  Error: could not install $pkg automatically. Install it manually:"
  echo "    macOS:         brew install $pkg"
  echo "    Debian/Ubuntu: sudo apt-get install -y $pkg"
  echo "    Alpine:        apk add $pkg"
  return 1
}

ensure_dep jq || exit 1
ensure_dep curl || exit 1
command -v npx >/dev/null 2>&1 || echo "  Note: Node.js (npx) not found — token cost section (ccusage) will show an install hint until available."

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Download scripts
echo "  Downloading statusline-command.sh..."
curl -fsSL "$RAW_BASE/statusline.sh" -o "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"

echo "  Downloading ccusage-cache.sh..."
curl -fsSL "$RAW_BASE/ccusage-cache.sh" -o "$CLAUDE_DIR/ccusage-cache.sh"
chmod +x "$CLAUDE_DIR/ccusage-cache.sh"

# Create default config if not present
if [ ! -f "$CONF_FILE" ]; then
  curl -fsSL "$RAW_BASE/statusline.conf.example" -o "$CONF_FILE"
  echo "  Created default statusline.conf"
else
  echo "  statusline.conf already exists — skipped"
fi

# Configure settings.json (non-interactive for pipe-to-bash)
if [ -f "$SETTINGS_FILE" ]; then
  if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo "  statusLine already configured — updating..."
  fi
  jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' \
    "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  echo "  Updated settings.json"
else
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
EOF
  echo "  Created settings.json"
fi

echo ""
echo "  Done! Restart Claude Code to see the new statusline."
echo ""
echo "  Config: ~/.claude/statusline.conf"
echo "  Optional: install Node.js for the token cost section (runs npx ccusage@latest)"
echo ""
