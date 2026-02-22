#!/usr/bin/env bash
# If no agent name given, show status for all agents
if [[ -n "${1:-}" ]]; then
  AGENT_NAME="$1"
  source "$(dirname "$0")/config.sh"

  echo "=== $AGENT_NAME ($(droplet_ip)) ==="
  remote '
    echo "=== Services ==="
    systemctl is-active openclaw 2>/dev/null && echo "openclaw: running" || echo "openclaw: not running"
    echo ""
    echo "=== Docker ==="
    docker --version 2>/dev/null || echo "not installed"
    echo ""
    echo "=== Node ==="
    node --version 2>/dev/null || echo "not in PATH"
    echo ""
    echo "=== OpenClaw ==="
    openclaw --version 2>/dev/null || echo "not in PATH"
    echo ""
    echo "=== Tailscale ==="
    sudo tailscale status 2>/dev/null || echo "not connected"
    echo ""
    echo "=== Firewall ==="
    sudo ufw status 2>/dev/null | head -5
  '
else
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  for dir in "$PROJECT_DIR"/agents/*/; do
    name=$(basename "$dir")
    if [[ -f "$dir/.droplet" ]]; then
      bash "$SCRIPT_DIR/status.sh" "$name"
      echo ""
    else
      echo "=== $name (not deployed) ==="
      echo ""
    fi
  done
fi
