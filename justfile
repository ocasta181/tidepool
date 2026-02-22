default:
    @just --list

# Create droplet and run ansible playbook
deploy agent:
    bash scripts/deploy.sh {{agent}}

# Destroy droplet and firewall
destroy agent:
    bash scripts/destroy.sh {{agent}}

# Bake a snapshot image for fast future deploys
bake:
    bash scripts/bake.sh

# Preview what will be created
plan agent:
    bash scripts/plan.sh {{agent}}

# Transfer local Claude credentials to the droplet
auth agent:
    bash scripts/auth.sh {{agent}}

# Automated onboarding: config, Slack, gateway daemon
onboard agent:
    bash scripts/onboard.sh {{agent}}

# Connect Google Workspace (Gmail, Calendar, Drive) — interactive, one-time per droplet
google-auth agent:
    bash scripts/google-auth.sh {{agent}}

# Apply security hardening to openclaw.json
secure agent:
    bash scripts/secure.sh {{agent}}

# SSH into the droplet as openclaw
ssh agent:
    bash scripts/ssh.sh {{agent}}

# SSH tunnel for dashboard (http://127.0.0.1:18789)
tunnel agent:
    bash scripts/tunnel.sh {{agent}}

# Check services and setup status (no arg = all agents)
status agent="":
    bash scripts/status.sh {{agent}}

# Tail OpenClaw gateway logs
logs agent:
    bash scripts/logs.sh {{agent}}

# Create a DO snapshot
snapshot agent:
    bash scripts/snapshot.sh {{agent}}

# Deploy all agents
deploy-all:
    #!/usr/bin/env bash
    for dir in agents/*/; do
      name=$(basename "$dir")
      echo "=== Deploying $name ==="
      bash scripts/deploy.sh "$name"
    done

# Destroy all agents
destroy-all:
    #!/usr/bin/env bash
    for dir in agents/*/; do
      name=$(basename "$dir")
      echo "=== Destroying $name ==="
      bash scripts/destroy.sh "$name"
    done
