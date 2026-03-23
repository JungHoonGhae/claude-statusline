#!/bin/bash
# Claude Statusline — Local Installer
# Copies scripts to ~/.claude/ and configures settings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CONF_FILE="$CLAUDE_DIR/statusline.conf"

echo "Installing Claude Code Custom Statusline..."
echo ""

# Check prerequisites
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required. Install: brew install jq (macOS) / sudo apt install jq (Linux)"; exit 1; }

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Copy scripts
cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline-command.sh"
cp "$SCRIPT_DIR/ccusage-cache.sh" "$CLAUDE_DIR/ccusage-cache.sh"
chmod +x "$CLAUDE_DIR/statusline-command.sh"
chmod +x "$CLAUDE_DIR/ccusage-cache.sh"
echo "  Copied statusline-command.sh"
echo "  Copied ccusage-cache.sh"

# Create default config if not present
if [ ! -f "$CONF_FILE" ]; then
  cp "$SCRIPT_DIR/statusline.conf.example" "$CONF_FILE"
  echo "  Created default statusline.conf"
else
  echo "  statusline.conf already exists — skipped"
fi

# Update settings.json
if [ -f "$SETTINGS_FILE" ]; then
  if jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
    echo ""
    echo "  statusLine is already configured in settings.json."
    echo "  Current: $(jq -r '.statusLine.command // "N/A"' "$SETTINGS_FILE")"
    echo ""
    read -p "  Overwrite? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "  Skipped settings.json update."
      echo ""
      echo "Done! Restart Claude Code to see the new statusline."
      exit 0
    fi
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
echo "Done! Restart Claude Code to see the new statusline."
echo ""
echo "Config: ~/.claude/statusline.conf"
echo "Optional: npm install -g ccusage (for token cost tracking)"
