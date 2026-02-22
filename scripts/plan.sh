#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

echo "Will create:"
echo "  Droplet:  $DROPLET_NAME ($DROPLET_SIZE, $DROPLET_REGION, $DROPLET_IMAGE)"
echo "  Firewall: ${DROPLET_NAME}-firewall (SSH + Tailscale in, all out)"
