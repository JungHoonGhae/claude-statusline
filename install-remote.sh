#!/bin/bash
# Claude Statusline — Remote One-Liner Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/junghoon-io/claude-statusline/main/install-remote.sh | bash

set -e

REPO="junghoon-io/claude-statusline"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CONF_FILE="$CLAUDE_DIR/statusline.conf"

echo ""
echo "  Claude Code Custom Statusline — Installer"
echo "  ─────────────────────────────────────────"
echo ""

# Check prerequisites
command -v jq >/dev/null 2>&1 || { echo "  Error: jq is required."; echo "    macOS:  brew install jq"; echo "    Linux:  sudo apt install jq"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "  Error: curl is required."; exit 1; }

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
echo "  Optional: npm install -g ccusage (for token cost tracking)"
echo ""
