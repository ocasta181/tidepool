#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

IP=$(require_droplet)

echo "Applying security configuration..."
remote 'bash -s' < "$(dirname "$0")/apply-security.sh"

echo "Running security audit..."
remote 'openclaw security audit --deep 2>/dev/null || echo "Security audit not available yet"'
remote 'openclaw doctor 2>/dev/null || echo "Doctor not available yet"'
