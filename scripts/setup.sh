#!/bin/bash
# Claude Statusline — Plugin Auto-Setup
# Runs on SessionStart via plugin hook.
# Copies scripts to ~/.claude/ and configures settings.json if needed.

set -e

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
CONF_FILE="$CLAUDE_DIR/statusline.conf"
TARGET_CMD="$CLAUDE_DIR/statusline-command.sh"
TARGET_CACHE="$CLAUDE_DIR/ccusage-cache.sh"

# Check jq
command -v jq >/dev/null 2>&1 || exit 0

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# Copy scripts (update if plugin version is newer)
cp "$PLUGIN_ROOT/statusline.sh" "$TARGET_CMD"
cp "$PLUGIN_ROOT/ccusage-cache.sh" "$TARGET_CACHE"
chmod +x "$TARGET_CMD" "$TARGET_CACHE"

# Create default config if not present
if [ ! -f "$CONF_FILE" ]; then
  cp "$PLUGIN_ROOT/statusline.conf.example" "$CONF_FILE"
fi

# Configure settings.json if statusLine is not set
if [ -f "$SETTINGS_FILE" ]; then
  if ! jq -e '.statusLine' "$SETTINGS_FILE" >/dev/null 2>&1; then
    jq '.statusLine = {"type": "command", "command": "bash ~/.claude/statusline-command.sh"}' \
      "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
  fi
else
  cat > "$SETTINGS_FILE" <<'EOF'
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
EOF
fi
