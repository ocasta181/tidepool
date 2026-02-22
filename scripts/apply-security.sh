#!/bin/bash
set -euo pipefail

# Applies security hardening to ~/.openclaw/openclaw.json
# Run on the droplet as the openclaw user.

CONFIG_DIR="$HOME/.openclaw"
CONFIG_FILE="$CONFIG_DIR/openclaw.json"

mkdir -p "$CONFIG_DIR"

SECURITY_CONFIG=$(cat <<'JSON'
{
  "gateway": {
    "bind": "loopback",
    "port": 18789,
    "controlUi": {
      "dangerouslyDisableDeviceAuth": false
    },
    "mdns": {
      "enabled": false
    }
  },
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "scope": "session",
        "docker": {
          "network": "none"
        }
      }
    }
  },
  "tools": {
    "profile": "default",
    "exec": {
      "safeBins": ["ls", "cat", "head", "tail", "grep", "find", "wc", "date", "echo", "pwd"],
      "host": "sandbox"
    }
  }
}
JSON
)

if [ -f "$CONFIG_FILE" ]; then
  # Merge: security config overlays existing config
  echo "$SECURITY_CONFIG" > /tmp/openclaw-security.json
  jq -s '.[0] * .[1]' "$CONFIG_FILE" /tmp/openclaw-security.json > /tmp/openclaw-merged.json
  mv /tmp/openclaw-merged.json "$CONFIG_FILE"
  rm -f /tmp/openclaw-security.json
  echo "Security settings merged into existing config."
else
  echo "$SECURITY_CONFIG" > "$CONFIG_FILE"
  echo "Security config created."
fi

chmod 600 "$CONFIG_FILE"
chmod 700 "$CONFIG_DIR"

# Secure credentials if they exist
if [ -d "$CONFIG_DIR/credentials" ]; then
  chmod 600 "$CONFIG_DIR/credentials/"* 2>/dev/null || true
fi

echo "File permissions set."
echo "Done."
