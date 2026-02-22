#!/bin/bash
set -euo pipefail

# Refreshes the Claude Max OAuth token and syncs it to OpenClaw's auth store.
# Deployed to the droplet and run via cron every 6 hours.
#
# How it works:
#   1. Runs a minimal Claude Code CLI command to trigger automatic token refresh
#   2. Reads the fresh access token from ~/.claude/.credentials.json
#   3. Updates OpenClaw's auth-profiles.json with the new token
#   4. Restarts the gateway to pick up the new token

PATH="/home/openclaw/.local/share/pnpm:/home/openclaw/.local/bin:$PATH"

CREDS_FILE="$HOME/.claude/.credentials.json"
AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
LOG_TAG="refresh-token"

log() { echo "[$(date -Iseconds)] [$LOG_TAG] $*"; }

if [[ ! -f "$CREDS_FILE" ]]; then
  log "ERROR: $CREDS_FILE not found"
  exit 1
fi

# Step 1: Trigger Claude Code CLI token refresh by running a no-op command.
# --print with an empty prompt exits immediately but still refreshes credentials.
log "Triggering Claude Code token refresh..."
claude --print "ping" --max-turns 0 > /dev/null 2>&1 || true

# Step 2: Read the fresh access token
NEW_TOKEN=$(python3 -c "
import json, sys
with open('$CREDS_FILE') as f:
    d = json.load(f)
print(d['claudeAiOauth']['accessToken'])
" 2>/dev/null)

if [[ -z "$NEW_TOKEN" ]]; then
  log "ERROR: Could not read access token from $CREDS_FILE"
  exit 1
fi

# Step 3: Read current token from OpenClaw auth store
if [[ -f "$AUTH_FILE" ]]; then
  OLD_TOKEN=$(python3 -c "
import json
with open('$AUTH_FILE') as f:
    d = json.load(f)
print(d.get('profiles', {}).get('anthropic:default', {}).get('token', ''))
" 2>/dev/null || echo "")
else
  OLD_TOKEN=""
fi

if [[ "$NEW_TOKEN" == "$OLD_TOKEN" ]]; then
  log "Token unchanged, skipping update."
  exit 0
fi

# Step 4: Update OpenClaw auth-profiles.json
log "Updating OpenClaw auth token..."
python3 -c "
import json
with open('$AUTH_FILE') as f:
    d = json.load(f)
d['profiles']['anthropic:default']['token'] = '$NEW_TOKEN'
with open('$AUTH_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"

# Step 5: Restart gateway to pick up new token
log "Restarting gateway..."
openclaw gateway restart > /dev/null 2>&1 || true

log "Token refreshed successfully."
