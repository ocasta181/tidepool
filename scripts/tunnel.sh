#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

IP=$(require_droplet)
echo "Dashboard: http://127.0.0.1:18789"
echo "Press Ctrl+C to close."
ssh -L 18789:127.0.0.1:18789 "${OPENCLAW_USER}@${IP}"
