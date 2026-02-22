#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

# Fully automated onboarding: sets up OpenClaw config, Claude Max auth with
# auto-refresh, Slack channel, and gateway systemd service. No interactive prompts.
#
# Requires in agents/<name>/agent.env:
#   SLACK_BOT_TOKEN  - Slack bot token (xoxb-...)
#   SLACK_APP_TOKEN  - Slack app-level token (xapp-...)
# Requires:
#   just auth <agent>  - must have been run first (Claude credentials on droplet)

IP=$(require_droplet)

# --- Validate required env vars ---

if [[ -z "${SLACK_BOT_TOKEN:-}" ]]; then
  echo "ERROR: SLACK_BOT_TOKEN not set in agents/$AGENT_NAME/agent.env"
  exit 1
fi

if [[ -z "${SLACK_APP_TOKEN:-}" ]]; then
  echo "ERROR: SLACK_APP_TOKEN not set in agents/$AGENT_NAME/agent.env"
  exit 1
fi

# --- 1. Run non-interactive onboard ---

echo "Running non-interactive onboard..."
remote "openclaw onboard --non-interactive --accept-risk \
  --auth-choice skip \
  --gateway-bind loopback \
  --install-daemon \
  --skip-channels \
  --skip-skills \
  --skip-ui"

# --- 2. Seed initial auth token from Claude credentials ---

echo "Seeding Claude Max auth token..."
CLAUDE_TOKEN=$(ssh "${OPENCLAW_USER}@${IP}" \
  "python3 -c \"import json; print(json.load(open('/home/openclaw/.claude/.credentials.json'))['claudeAiOauth']['accessToken'])\"" 2>/dev/null)

if [[ -z "$CLAUDE_TOKEN" ]]; then
  echo "ERROR: Could not read Claude credentials. Run 'just auth $AGENT_NAME' first."
  exit 1
fi

echo "$CLAUDE_TOKEN" | ssh "${OPENCLAW_USER}@${IP}" \
  "PATH=${REMOTE_PATH}:\$PATH openclaw models auth paste-token --provider anthropic"

# --- 3. Deploy token refresh script and cron job ---

echo "Installing token refresh cron job..."
scp "${SCRIPT_DIR}/refresh-token.sh" "${OPENCLAW_USER}@${IP}:~/.openclaw/refresh-token.sh"
remote "chmod +x ~/.openclaw/refresh-token.sh"

# Install cron: run every 6 hours, log to file
remote 'crontab -l 2>/dev/null | grep -v refresh-token || true' > /tmp/openclaw-cron
echo "0 */6 * * * /home/openclaw/.openclaw/refresh-token.sh >> /home/openclaw/.openclaw/logs/refresh.log 2>&1" >> /tmp/openclaw-cron
scp /tmp/openclaw-cron "${OPENCLAW_USER}@${IP}:/tmp/openclaw-cron"
remote "crontab /tmp/openclaw-cron && rm /tmp/openclaw-cron"
rm -f /tmp/openclaw-cron

# Run refresh once now to verify it works
echo "Running initial token refresh..."
remote "~/.openclaw/refresh-token.sh"

# --- 4. Enable Slack plugin and add channel ---

echo "Enabling Slack plugin..."
remote "openclaw plugins enable slack"

echo "Adding Slack channel..."
remote "openclaw channels add --channel slack \
  --bot-token '${SLACK_BOT_TOKEN}' \
  --app-token '${SLACK_APP_TOKEN}'"

# Disable thread replies in DMs (send flat messages instead)
remote "openclaw config set channels.slack.replyToMode off"

# --- 5. Restart gateway ---

echo "Restarting gateway..."
remote "openclaw gateway restart"

# --- 6. Verify ---

echo ""
echo "=== Verification ==="
echo ""
remote "openclaw models status 2>&1"
echo ""
remote "openclaw channels status 2>&1"

echo ""
echo "=== Onboarding complete ==="
echo ""
echo "Next steps:"
echo "  just secure $AGENT_NAME    Apply security hardening"
echo "  just status $AGENT_NAME    Check all services"
echo "  Message the bot on Slack to test"
