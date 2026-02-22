# OpenClaw on DigitalOcean: Architecture & Implementation Guide

## 1. Overview

Deploy a single OpenClaw agent on a DigitalOcean Droplet, accessible via Telegram, running 24/7 on Claude Max. This document is a spec that Claude Code will execute against to provision and configure the entire stack.

**What OpenClaw is:** A Node.js agentic runtime that connects an LLM to real-world tools (shell, file I/O, headless Chrome, web search) and messaging channels. It maintains persistent memory via markdown files and SQLite. The "Gateway" is the long-running server process.

**Constraints:**
- Must run on cloud infrastructure, not the owner's laptop
- $5,000 in DigitalOcean credits available
- LLM via Claude Max subscription (no standalone API key)
- Single agent, single droplet for v1

---

## 2. V1 Architecture (Current Scope)

```
Owner's Phone/Laptop
        |
        | Telegram
        v
  ┌─────────────┐
  │  Telegram    │  (Telegram's servers, not ours)
  │  BotFather   │
  └──────┬──────┘
         |
         v
  ┌──────────────────────────┐
  │  DO Droplet (4vCPU/8GB)  │
  │                          │
  │  ┌────────────────────┐  │
  │  │  OpenClaw Gateway   │  │
  │  │  ws://127.0.0.1:   │  │
  │  │       18789         │  │
  │  └────────┬───────────┘  │
  │           |              │
  │  ┌────────┴───────────┐  │
  │  │  Claude Max        │  │
  │  │  (via scp'd OAuth) │  │
  │  └────────────────────┘  │
  │                          │
  │  ┌────────────────────┐  │
  │  │  Docker Sandbox    │  │
  │  │  (tool execution)  │  │
  │  └────────────────────┘  │
  │                          │
  │  Tailscale for remote    │
  │  dashboard access        │
  └──────────────────────────┘
```

**What's NOT in v1:**
- No shared memory repo (memory stays local on the droplet)
- No multi-agent swarm
- No agent budgets or autonomous spawning
- No Matrix or Mattermost
- No OpenRouter fallback

---

## 3. Infrastructure

### Droplet Spec

| Spec | Value |
|------|-------|
| Size | s-4vcpu-8gb |
| RAM | 8 GB |
| Disk | 160 GB SSD |
| OS | Ubuntu 24.04 LTS |
| Cost | $48/mo (~8.5 years on $5k credits) |

The 8 GB gives headroom for Docker sandboxing and headless Chrome. Overkill for a single agent, but positions well for later expansion.

### Region

Pick the DO region with lowest latency to the owner's primary location. Default: `sfo3` (San Francisco).

---

## 4. Provisioning via openclaw-ansible

Use the official Ansible playbook for automated hardened deployment.

### Prerequisites (on the fresh droplet)

```bash
sudo apt update && sudo apt install -y ansible git
git clone https://github.com/openclaw/openclaw-ansible.git
cd openclaw-ansible
```

### What the playbook does

- Creates non-root `openclaw` user
- Installs and configures UFW firewall
- Installs Docker Engine with isolation
- Installs Tailscale VPN (no ports exposed to public internet)
- Sets up fail2ban for SSH brute-force protection
- Installs Node.js and OpenClaw
- Creates systemd service with security hardening

### Run it

```bash
./run-playbook.sh
```

### Post-playbook manual steps

```bash
# Switch to openclaw user
su - openclaw

# Run onboarding wizard
openclaw onboard --install-daemon

# The wizard prompts for:
# 1. Model provider -> Anthropic
# 2. Auth method -> setup-token
# 3. Model selection -> claude-opus-4-5
# 4. Channels -> Telegram
```

---

## 5. Claude Max Authentication

The owner has a Claude Max subscription. No standalone API key.

### Method: scp credentials from local machine

The owner has already run `claude login` locally. Transfer the OAuth tokens to the droplet:

```bash
# From owner's local machine
scp -r ~/.claude/ openclaw@<droplet_ip>:~/
```

This avoids the headless OAuth browser flow entirely.

### On the droplet

```bash
# Verify credentials work
su - openclaw
claude --version  # should show authenticated state

# Generate setup token for OpenClaw
claude setup-token
# Provide this during openclaw onboard
```

### Fallback: claude-max-api-proxy

If direct token transfer doesn't work, install the proxy:

```bash
npm install -g claude-max-api-proxy
claude-max-api-proxy  # runs on localhost:3456
```

Then configure OpenClaw to point at it as an OpenAI-compatible endpoint:

```json
{
  "env": {
    "OPENAI_API_KEY": "not-needed",
    "OPENAI_BASE_URL": "http://localhost:3456/v1"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "openai/claude-opus-4"
      }
    }
  }
}
```

### Rate Limits

Claude Max provides roughly 3.5 hours of active use per day. When limits are hit, the model silently degrades (gives bad responses rather than erroring). This is a known pain point. OpenRouter fallback is a future optimization (see Section 10).

---

## 6. Telegram Channel Setup

### Create bot via BotFather

1. Open Telegram, message @BotFather
2. `/newbot` -> pick a name and username
3. BotFather gives you a token like `7123456789:AAF...`
4. Save the token

### Configure in OpenClaw

Either via the onboarding wizard or manually in `~/.openclaw/openclaw.json`:

```json
{
  "channels": {
    "telegram": {
      "enabled": true,
      "accounts": [
        {
          "token": "<BOTFATHER_TOKEN>",
          "dm": {
            "policy": "pairing"
          }
        }
      ]
    }
  }
}
```

DM pairing (`policy: "pairing"`) means the bot will only respond to the owner after an initial pairing handshake, preventing random people from messaging it.

### Test it

Message the bot on Telegram. First message triggers DM pairing. After pairing, the agent responds normally.

---

## 7. Security

### Network

- Gateway binds to `127.0.0.1` only (never `0.0.0.0`)
- UFW blocks all inbound except SSH (from Tailscale range only)
- Port 18789 accessible only via Tailscale or SSH tunnel
- mDNS disabled (cloud server, not LAN device)
- fail2ban protects SSH

### Docker Sandboxing

Enable in `openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",
        "scope": "session",
        "docker": {
          "network": "none"
        }
      }
    }
  }
}
```

- `mode: "all"` -- every session runs in a Docker container
- `scope: "session"` -- one container per session
- `docker.network: "none"` -- sandbox containers have no network access (the gateway's web tools handle external requests)

### File Permissions

```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
chmod 600 ~/.openclaw/credentials/*
```

### Validation

```bash
openclaw security audit
openclaw security audit --deep
openclaw doctor
```

---

## 8. Remote Dashboard Access

### Option A: SSH Tunnel (quick and dirty)

```bash
# From owner's laptop
ssh -L 18789:127.0.0.1:18789 openclaw@<droplet_ip>
# Then open http://127.0.0.1:18789
```

### Option B: Tailscale (recommended, persistent)

openclaw-ansible installs Tailscale automatically. After playbook:

```bash
# On the droplet (already done by ansible)
sudo tailscale up

# On owner's devices: install Tailscale, join same tailnet
# Access dashboard via: http://<droplet_tailscale_ip>:18789
```

Works from phone, laptop, anywhere. No port exposure.

---

## 9. Backup

OpenClaw state is file-based. Critical paths:

```
~/.openclaw/openclaw.json
~/.openclaw/credentials/
~/.openclaw/state/
~/.openclaw/workspace/  (SOUL.md, USER.md, skills)
~/.claude/              (Claude Max OAuth tokens)
```

**Enable DO automated backups.** Adds ~$10/mo (20% of droplet cost). Cheap insurance.

```bash
# Or manual snapshot via doctl
doctl compute droplet-action snapshot <droplet_id> --snapshot-name "openclaw-$(date +%Y%m%d)"
```

---

## 10. Future Roadmap

These are documented for later implementation. None are in v1 scope.

### 10.1 Multi-Agent Swarm via Matrix

Expand from single Telegram bot to a fleet of agents coordinating through Matrix:

- Each agent gets its own DO droplet (separate 4vCPU/8GB instance)
- Self-hosted Matrix homeserver (Conduit or Dendrite, single binary, minimal resources) on a dedicated small droplet
- OpenClaw has first-party Matrix plugin with E2EE, multi-agent identities, room management, auto-join
- Each Matrix homeserver node maintains full room history (the replication model the owner wants)
- Agents coordinate via Matrix rooms; the owner interacts via Element (mobile + desktop)
- Telegram remains as a convenient mobile interface for quick interactions

**Why Matrix over Mattermost:** Matrix is a true federated protocol where each homeserver maintains complete room history. Conduit (Rust, single binary, SQLite) is dramatically simpler to set up than Mattermost (Docker Compose + Postgres + NGINX). Matrix also natively gives per-node full replication, which aligns with the owner's desire for data survival as long as >=1 node exists.

### 10.2 Shared Memory Layer

Move agent memory from local-to-each-droplet to a shared layer:

- Git repo as source of truth (agents read/write .md files, push to shared repo)
- Each agent clones the repo, reads/writes locally, pushes changes
- View/edit via GitHub web UI initially, self-hosted Gitea/GitLab later
- Optional: lightweight sync script to mirror Git <-> Notion for nice UI
- Eventual goal: fully self-hosted (no GitHub dependency)

### 10.3 Agent Budgets and Autonomous Spawning

Parent agents can spin up child agents, including provisioning new infrastructure:

**Budget system:**
- Budgets denominated in USD
- Near-term: each agent has a Solana wallet; pays into a central account when taking actions that cost money
- Long-term: integrate with a neobank (Mercury, Bluevine) so agents can spin up virtual debit cards with spend limits
- Budget is hierarchical: parent grants child a sub-budget deducted from its own

**Autonomous spawning:**
- Parent agent calls a provisioning service to stand up a new droplet
- The service runs openclaw-ansible on the new droplet
- Creates a new TG bot (or Matrix account) for the child
- Configures the child agent with its own workspace, personality, and budget
- Cost of provisioning (droplet + bot setup) is deducted from parent's budget

**External ledger:**
- Solana wallet per agent (cheap transactions, programmable)
- Smart contract or simple program enforces budget caps
- All spend is auditable on-chain

This is the most complex future work item and requires careful design around authorization, budget enforcement, and preventing runaway spend.

### 10.4 OpenRouter Fallback

When Claude Max rate limits (3.5 hrs/day active use) become a bottleneck:

- Configure OpenRouter as a fallback provider
- Recommended overflow model: Kimi K2.5 by Moonshot AI (~$0.90/million tokens)
- OpenClaw supports model failover natively in config

### 10.5 Decentralized Messaging (Long-term Research)

The owner expressed interest in a fully blockchain-based messaging backbone (e.g., built on Lens Protocol or similar). No turnkey solution exists today that integrates with OpenClaw. This would require building a custom OpenClaw channel plugin. Parking this as a research item.

---

## 11. Implementation Checklist (V1)

Claude Code should execute these in order:

- [ ] Provision DO droplet (s-4vcpu-8gb, Ubuntu 24.04, SSH key, sfo3 or nearest region)
- [ ] SSH in as root, install ansible + git
- [ ] Clone openclaw-ansible, run playbook
- [ ] scp ~/.claude/ credentials from owner's local machine to droplet
- [ ] Run `openclaw onboard --install-daemon` as openclaw user
- [ ] Configure Claude Max as LLM provider (setup-token method)
- [ ] Create Telegram bot via BotFather, add token to config
- [ ] Enable Docker sandboxing in openclaw.json
- [ ] Disable mDNS, verify gateway binds to loopback
- [ ] Set file permissions (700/600)
- [ ] Run `openclaw security audit --deep` and `openclaw doctor`
- [ ] Set up Tailscale on owner's devices, verify dashboard access
- [ ] Enable DO automated backups
- [ ] Send first message via Telegram, complete DM pairing
- [ ] Walk through BOOTSTRAP.md (agent naming, personality, USER.md)
- [ ] Test basic capabilities (file ops, web search, shell commands)

---

## 12. Known Issues

1. **Claude Max rate limiting is silent.** When limits are hit, the model doesn't error; it gives degraded/incoherent responses. Monitor for this.

2. **`claude login` on headless servers is painful.** That's why we scp credentials instead of running OAuth on the droplet. If tokens expire, re-scp from local machine.

3. **Anthropic's TOS on Max with third-party tools:** As of February 2026, Anthropic confirmed personal use of Max subscriptions with tools like OpenClaw is fine.

4. **Browser automation in sandbox** requires additional Docker config (Chrome inside the container). The default sandbox image may not include all needed dependencies. Test browser tools early.

5. **Skills that need network access will fail in sandbox** when `docker.network` is `"none"`. The gateway's own web tools (web_fetch, web_search) run outside the sandbox and are the intended path.

6. **openclaw-ansible self-update script** sometimes fails due to git permissions. Manual `git pull` and rebuild may be needed.