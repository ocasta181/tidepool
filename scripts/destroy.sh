#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

# Delete firewall
FW_ID=$(doctl compute firewall list --format ID,Name --no-header | grep "${DROPLET_NAME}-firewall" | awk '{print $1}' || true)
if [[ -n "$FW_ID" ]]; then
  echo "Deleting firewall..."
  doctl compute firewall delete "$FW_ID" --force
fi

# Delete droplet
ID=$(droplet_id)
if [[ -n "$ID" ]]; then
  echo "Deleting droplet..."
  doctl compute droplet delete "$ID" --force
else
  echo "No droplet found."
fi

rm -f "$STATE_FILE"
echo "Done."
