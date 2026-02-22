#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

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
