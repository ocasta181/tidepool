#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

IP=$(require_droplet)
ssh "${OPENCLAW_USER}@${IP}"
