#!/usr/bin/env bash
# Shared configuration and utilities for all scripts.
# Source this at the top of every script: source "$(dirname "$0")/config.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env if it exists
if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

# Configure doctl to use the token from .env
if [[ -n "${DO_TOKEN:-}" ]]; then
  export DIGITALOCEAN_ACCESS_TOKEN="$DO_TOKEN"
fi

# Droplet config
DROPLET_NAME="${DROPLET_NAME:-openclaw}"
DROPLET_REGION="${DROPLET_REGION:-sfo3}"
DROPLET_SIZE="${DROPLET_SIZE:-s-4vcpu-8gb}"
DROPLET_IMAGE="${DROPLET_IMAGE:-ubuntu-24-04-x64}"
STATE_FILE="$PROJECT_DIR/.droplet"
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
    echo "No droplet. Run 'just deploy' first."
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
