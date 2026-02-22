#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

# Interactive: pushes Google OAuth client secret to the droplet and runs the
# gog auth flow. Outputs a URL to open in your browser. One-time per droplet.
#
# Requires:
#   client_secret.json in the project root (from Google Cloud Console)
#   GOOGLE_ACCOUNT in .env (your Google email address)

IP=$(require_droplet)

CLIENT_SECRET="$PROJECT_DIR/client_secret.json"
if [[ ! -f "$CLIENT_SECRET" ]]; then
  echo "ERROR: client_secret.json not found in project root."
  echo "Download it from Google Cloud Console → Credentials → OAuth client ID → Desktop app."
  exit 1
fi

if [[ -z "${GOOGLE_ACCOUNT:-}" ]]; then
  echo "ERROR: GOOGLE_ACCOUNT not set in .env (your Google email address)"
  exit 1
fi

# Push client secret to droplet
echo "Pushing Google OAuth credentials to droplet..."
scp "$CLIENT_SECRET" "${OPENCLAW_USER}@${IP}:~/client_secret.json"

# Register credentials with gog
echo "Registering credentials with gog..."
remote "gog auth credentials ~/client_secret.json"

# Run interactive OAuth flow (requires browser)
echo ""
echo "Starting Google OAuth flow..."
echo "This will print a URL — open it in your browser to authorize."
echo ""
ssh -t "${OPENCLAW_USER}@${IP}" "PATH=${REMOTE_PATH}:\$PATH gog auth add ${GOOGLE_ACCOUNT} --services gmail,calendar,drive,contacts,docs,sheets"

echo ""
echo "Verifying..."
remote "gog auth list"

echo ""
echo "Google Workspace auth complete."
