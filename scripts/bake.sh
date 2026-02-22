#!/usr/bin/env bash
AGENT_NAME="${1:-bake}"
source "$(dirname "$0")/config.sh"

# Builds a pre-configured DO snapshot so future deploys boot in ~30 seconds.
#
# Flow:
#   1. Create a temporary droplet
#   2. Run the ansible playbook on it
#   3. Snapshot it
#   4. Destroy the temporary droplet
#   5. Save the snapshot ID to .snapshot

SNAPSHOT_FILE="$PROJECT_DIR/.snapshot"
TEMP_NAME="${DROPLET_NAME}-bake-$(date +%s)"

echo "=== Baking OpenClaw image ==="

# Create temporary droplet
echo "Creating temporary droplet for image build..."
DROPLET_ID=$(doctl compute droplet create "$TEMP_NAME" \
  --region "$DROPLET_REGION" \
  --size "$DROPLET_SIZE" \
  --image "$DROPLET_IMAGE" \
  --ssh-keys "$(doctl compute ssh-key list --format ID --no-header | head -1)" \
  --tag-name openclaw-bake \
  --wait \
  --format ID \
  --no-header)

IP=$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)
echo "Temp droplet: $IP (ID: $DROPLET_ID)"

# Wait for SSH
echo "Waiting for SSH..."
for i in $(seq 1 30); do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@${IP}" 'echo ok' 2>/dev/null; then
    break
  fi
  echo "  attempt $i/30..."
  sleep 10
done

# Run ansible
echo "Running ansible setup..."
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

  # Clean up for snapshotting
  echo "Cleaning up for snapshot..."
  apt-get clean
  rm -rf /root/openclaw-ansible
  rm -rf /tmp/*
  cloud-init clean --logs
REMOTE

# Power off before snapshot (cleaner image)
echo "Powering off for snapshot..."
doctl compute droplet-action power-off "$DROPLET_ID" --wait

# Snapshot
SNAPSHOT_NAME="openclaw-$(date +%Y%m%d-%H%M)"
echo "Creating snapshot: $SNAPSHOT_NAME..."
doctl compute droplet-action snapshot "$DROPLET_ID" \
  --snapshot-name "$SNAPSHOT_NAME" \
  --wait

# Get snapshot ID
SNAPSHOT_ID=$(doctl compute snapshot list --format ID,Name --no-header | grep "$SNAPSHOT_NAME" | awk '{print $1}')
echo "$SNAPSHOT_ID" > "$SNAPSHOT_FILE"
echo "Snapshot saved: $SNAPSHOT_ID ($SNAPSHOT_NAME)"

# Destroy temp droplet
echo "Destroying temporary droplet..."
doctl compute droplet delete "$DROPLET_ID" --force

echo ""
echo "=== Image baked ==="
echo "Snapshot ID: $SNAPSHOT_ID"
echo "Run 'just deploy <agent>' to boot from this image."
