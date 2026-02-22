#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

IP=$(require_droplet)

echo "Launching interactive onboarding on the droplet..."
echo "When prompted:"
echo "  Provider:   Anthropic"
echo "  Auth:       setup-token (run 'claude setup-token' in another terminal)"
echo "  Model:      claude-opus-4-5"
echo "  Channel:    Telegram (provide BotFather token)"
echo ""
ssh -t "${OPENCLAW_USER}@${IP}" 'openclaw onboard --install-daemon'
