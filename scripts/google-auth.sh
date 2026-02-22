#!/usr/bin/env bash
AGENT_NAME="${1:?Usage: $0 <agent-name>}"
source "$(dirname "$0")/config.sh"

# Interactive: pushes Google OAuth client secret to the droplet and runs the
# gog auth flow. Outputs a URL to open in your browser. One-time per droplet.
#
# Requires:
#   client_secret.json in the project root (from Google Cloud Console)
#   GOOGLE_ACCOUNT in agents/<name>/agent.env (your Google email address)

IP=$(require_droplet)

CLIENT_SECRET="$PROJECT_DIR/client_secret.json"
if [[ ! -f "$CLIENT_SECRET" ]]; then
  echo "ERROR: client_secret.json not found in project root."
  echo "Download it from Google Cloud Console → Credentials → OAuth client ID → Desktop app."
  exit 1
fi

if [[ -z "${GOOGLE_ACCOUNT:-}" ]]; then
  echo "ERROR: GOOGLE_ACCOUNT not set in agents/$AGENT_NAME/agent.env"
  exit 1
fi

# Push client secret to droplet
echo "Pushing Google OAuth credentials to droplet..."
scp "$CLIENT_SECRET" "${OPENCLAW_USER}@${IP}:~/client_secret.json"

# gog needs a keyring password on headless servers (no GUI keyring available).
# GOG_KEYRING_PASSWORD can be set in .env; defaults to 'openclaw' if unset.
GOG_KR_PASS="${GOG_KEYRING_PASSWORD:-openclaw}"
GOG_ENV="GOG_KEYRING_PASSWORD='${GOG_KR_PASS}'"

# Register credentials with gog
echo "Registering credentials with gog..."
remote "${GOG_ENV} gog auth credentials ~/client_secret.json"

# Run remote OAuth flow (two-step: prints URL, then exchanges code)
# This avoids the localhost callback problem when running on a remote server.
echo ""
echo "=== Step 1: Getting authorization URL ==="
echo ""
AUTH_URL=$(remote "${GOG_ENV} gog auth add ${GOOGLE_ACCOUNT} --services gmail,calendar,drive,contacts,docs,sheets --remote --step 1 --plain 2>&1")
echo "Open this URL in your browser and authorize:"
echo ""
echo "$AUTH_URL"
echo ""
echo "After authorizing, Google will redirect you to a URL starting with http://127.0.0.1/..."
echo "Copy the FULL redirect URL from your browser's address bar (even if the page shows an error)."
echo ""
read -rp "Paste the redirect URL here: " REDIRECT_URL

echo ""
echo "=== Step 2: Exchanging authorization code ==="
echo ""
remote "${GOG_ENV} gog auth add ${GOOGLE_ACCOUNT} --services gmail,calendar,drive,contacts,docs,sheets --remote --step 2 --auth-url '${REDIRECT_URL}'"

echo ""
echo "Verifying..."
remote "${GOG_ENV} gog auth list"

echo ""
echo "Google Workspace auth complete."
