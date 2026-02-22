#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

remote 'sudo journalctl -u openclaw -f --no-pager'
