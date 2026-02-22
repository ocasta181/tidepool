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

# SSH in and run openclaw onboard (interactive)
onboard:
    bash scripts/onboard.sh

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
