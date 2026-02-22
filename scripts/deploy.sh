#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

SNAPSHOT_FILE="$PROJECT_DIR/.snapshot"

if [[ -f "$STATE_FILE" ]]; then
  echo "Droplet already exists at $(cat "$STATE_FILE"). Run 'just destroy' first."
  exit 1
fi

# Decide image: baked snapshot or stock Ubuntu
if [[ -f "$SNAPSHOT_FILE" ]]; then
  IMAGE=$(cat "$SNAPSHOT_FILE")
  echo "Deploying from baked snapshot: $IMAGE"
  FROM_SNAPSHOT=true
else
  IMAGE="$DROPLET_IMAGE"
  echo "No snapshot found. Deploying from stock image (slow — run 'just bake' after to speed up future deploys)."
  FROM_SNAPSHOT=false
fi

# Create droplet
echo "Creating droplet..."
DROPLET_ID=$(doctl compute droplet create "$DROPLET_NAME" \
  --region "$DROPLET_REGION" \
  --size "$DROPLET_SIZE" \
  --image "$IMAGE" \
  --ssh-keys "$(doctl compute ssh-key list --format ID --no-header | head -1)" \
  --tag-name openclaw \
  --wait \
  --format ID \
  --no-header)

IP=$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)
echo "$IP" > "$STATE_FILE"
echo "Droplet created: $IP (ID: $DROPLET_ID)"

# Create firewall
echo "Creating firewall..."
doctl compute firewall create \
  --name "${DROPLET_NAME}-firewall" \
  --droplet-ids "$DROPLET_ID" \
  --inbound-rules "protocol:tcp,ports:22,address:0.0.0.0/0,address:::/0 protocol:udp,ports:41641,address:0.0.0.0/0,address:::/0" \
  --outbound-rules "protocol:tcp,ports:1-65535,address:0.0.0.0/0,address:::/0 protocol:udp,ports:1-65535,address:0.0.0.0/0,address:::/0 protocol:icmp,address:0.0.0.0/0,address:::/0" \
  --format ID,Name \
  --no-header

# Wait for SSH
echo "Waiting for SSH..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@${IP}" 'echo ok' 2>/dev/null; then
    break
  fi
  echo "  attempt $i/30..."
  sleep 10
done

# If from snapshot, just inject SSH key and we're done.
# If from stock image, run full ansible setup.
if [[ "$FROM_SNAPSHOT" == "true" ]]; then
  echo "Snapshot booted. Injecting SSH key for openclaw user..."
  SSH_PUBKEY=$(cat ~/.ssh/id_rsa.pub)
  ssh "root@${IP}" bash <<REMOTE
    mkdir -p /home/openclaw/.ssh
    echo "$SSH_PUBKEY" >> /home/openclaw/.ssh/authorized_keys
    sort -u -o /home/openclaw/.ssh/authorized_keys /home/openclaw/.ssh/authorized_keys
    chown -R openclaw:openclaw /home/openclaw/.ssh
    chmod 700 /home/openclaw/.ssh
    chmod 600 /home/openclaw/.ssh/authorized_keys
REMOTE
else
  echo "Running ansible setup (this takes a few minutes)..."
  SSH_PUBKEY=$(cat ~/.ssh/id_rsa.pub)
  ssh "root@${IP}" bash <<REMOTE
    set -e
    echo "Waiting for cloud-init..."
    cloud-init status --wait

    echo "Installing ansible and git..."
    apt-get update -qq
    apt-get install -y -qq ansible git > /dev/null 2>&1

    echo "Cloning openclaw-ansible..."
    git clone https://github.com/openclaw/openclaw-ansible.git /root/openclaw-ansible
    cd /root/openclaw-ansible
    ansible-galaxy collection install -r requirements.yml > /dev/null 2>&1

    echo "Running ansible playbook..."
    ./run-playbook.sh \
      -e "openclaw_ssh_keys=['$SSH_PUBKEY']" \
      -e tailscale_enabled=true
REMOTE

  # Post-ansible setup: install Claude Code CLI, gog CLI, and fix pnpm ownership
  echo "Installing Claude Code CLI and gog CLI..."
  ssh "root@${IP}" bash <<'POSTSETUP'
    set -e
    su - openclaw -c "pnpm install -g @anthropic-ai/claude-code"
    chown -R openclaw:openclaw /home/openclaw/.local/share/pnpm

    # Install gog (Google Workspace CLI) from pre-built binary
    curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.11.0/gogcli_0.11.0_linux_amd64.tar.gz \
      | tar xz -C /tmp
    mv /tmp/gog /usr/local/bin/gog
    chmod +x /usr/local/bin/gog
POSTSETUP
fi

echo ""
echo "=== Droplet ready at $IP ==="
echo ""
echo "Next steps:"
echo "  just auth      Transfer Claude Max credentials"
echo "  just onboard   Run OpenClaw onboarding wizard"
echo "  just tunnel    Access the dashboard"
