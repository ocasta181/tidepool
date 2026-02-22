default:
    @just --list

# Create droplet and run ansible playbook
deploy:
    bash scripts/deploy.sh

# Destroy droplet and firewall
destroy:
    bash scripts/destroy.sh

# Bake a snapshot image for fast future deploys
bake:
    bash scripts/bake.sh

# Preview what will be created
plan:
    bash scripts/plan.sh

# Transfer local Claude credentials to the droplet
auth:
    bash scripts/auth.sh

# Automated onboarding: config, Slack, gateway daemon
onboard:
    bash scripts/onboard.sh

# Connect Google Workspace (Gmail, Calendar, Drive) — interactive, one-time per droplet
google-auth:
    bash scripts/google-auth.sh

# Apply security hardening to openclaw.json
secure:
    bash scripts/secure.sh

# SSH into the droplet as openclaw
ssh:
    bash scripts/ssh.sh

# SSH tunnel for dashboard (http://127.0.0.1:18789)
tunnel:
    bash scripts/tunnel.sh

# Check services and setup status
status:
    bash scripts/status.sh

# Tail OpenClaw gateway logs
logs:
    bash scripts/logs.sh

# Create a DO snapshot
snapshot:
    bash scripts/snapshot.sh
