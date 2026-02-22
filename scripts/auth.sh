#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

# Extracts the Claude Code OAuth token from macOS Keychain and writes it
# to the droplet's credential store so Claude Code CLI works remotely.

IP=$(require_droplet)

echo "Extracting Claude Code credentials from macOS Keychain..."
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [[ -z "$CREDS" ]]; then
  echo "ERROR: No Claude Code credentials found in Keychain."
  echo "Run 'claude login' locally first."
  exit 1
fi

echo "Writing credentials to droplet..."
remote "mkdir -p ~/.claude && chmod 700 ~/.claude"

# Claude Code on Linux reads from ~/.claude/.credentials.json
echo "$CREDS" | ssh "${OPENCLAW_USER}@${IP}" 'cat > ~/.claude/.credentials.json && chmod 600 ~/.claude/.credentials.json'

echo "Verifying Claude Code on droplet..."
remote 'claude --version 2>/dev/null && echo "Claude CLI OK" || echo "WARNING: claude not in PATH (may need: source ~/.bashrc)"'

echo ""
echo "Done. Next: just onboard"
