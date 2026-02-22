#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

ID=$(droplet_id)
[[ -n "$ID" ]] || { echo "No droplet named '$DROPLET_NAME' found."; exit 1; }

doctl compute droplet-action snapshot "$ID" --snapshot-name "${DROPLET_NAME}-$(date +%Y%m%d-%H%M)"
echo "Snapshot requested."
