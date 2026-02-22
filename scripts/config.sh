#!/usr/bin/env bash
# Shared configuration and utilities for all scripts.
# Source this at the top of every script: source "$(dirname "$0")/config.sh"
#
# Scripts must set AGENT_NAME before sourcing this file.
# Per-agent config lives in agents/<name>/agent.env and agents/<name>/.droplet

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load global .env if it exists (DO_TOKEN, etc.)
if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

# Configure doctl to use the token from .env
if [[ -n "${DO_TOKEN:-}" ]]; then
  export DIGITALOCEAN_ACCESS_TOKEN="$DO_TOKEN"
fi

# --- Agent config ---

require_agent() {
  if [[ -z "${AGENT_NAME:-}" ]]; then
    echo "ERROR: No agent name provided. Usage: $0 <agent-name>"
    exit 1
  fi
  AGENT_DIR="$PROJECT_DIR/agents/$AGENT_NAME"
  if [[ ! -d "$AGENT_DIR" ]]; then
    echo "ERROR: Agent directory not found: agents/$AGENT_NAME/"
    echo "Create it with: mkdir -p agents/$AGENT_NAME"
    exit 1
  fi
}

# If AGENT_NAME is set, load per-agent config
if [[ -n "${AGENT_NAME:-}" ]]; then
  require_agent
  # Load per-agent env (SLACK_BOT_TOKEN, SLACK_APP_TOKEN, GOOGLE_ACCOUNT, etc.)
  if [[ -f "$AGENT_DIR/agent.env" ]]; then
    set -a
    source "$AGENT_DIR/agent.env"
    set +a
  fi
  STATE_FILE="$AGENT_DIR/.droplet"
  DROPLET_NAME="openclaw-${AGENT_NAME}"
else
  # Fallback for agent-less commands (shouldn't normally happen)
  STATE_FILE="$PROJECT_DIR/.droplet"
  DROPLET_NAME="${DROPLET_NAME:-openclaw}"
fi

# Droplet defaults (can be overridden in agent.env or .env)
DROPLET_REGION="${DROPLET_REGION:-sfo3}"
DROPLET_SIZE="${DROPLET_SIZE:-s-4vcpu-8gb}"
DROPLET_IMAGE="${DROPLET_IMAGE:-ubuntu-24-04-x64}"
OPENCLAW_USER="openclaw"

# --- Utilities ---

# Read the droplet IP from state file, or empty string if not deployed
droplet_ip() {
  cat "$STATE_FILE" 2>/dev/null || echo ""
}

# Require a deployed droplet, exit if not found
require_droplet() {
  local ip
  ip=$(droplet_ip)
  if [[ -z "$ip" ]]; then
    echo "No droplet for agent '$AGENT_NAME'. Run 'just deploy $AGENT_NAME' first."
    exit 1
  fi
  echo "$ip"
}

# Get the droplet ID by name from doctl
droplet_id() {
  doctl compute droplet list --format ID,Name --no-header | grep "$DROPLET_NAME" | awk '{print $1}' || true
}

# SSH to the droplet as the openclaw user
# .bashrc exits early for non-interactive shells, so we prepend the pnpm PATH explicitly
REMOTE_PATH="/home/openclaw/.local/share/pnpm:/home/openclaw/.local/bin"
remote() {
  local ip
  ip=$(require_droplet)
  ssh "${OPENCLAW_USER}@${ip}" "PATH=${REMOTE_PATH}:\$PATH $*"
}

# SSH to the droplet as root
remote_root() {
  local ip
  ip=$(require_droplet)
  ssh "root@${ip}" "$@"
}
