# Tidepool

Deploy [OpenClaw](https://openclaw.ai) on a DigitalOcean Droplet. Single agent, running 24/7 on Claude Max, accessible via Telegram.

## Prerequisites

- [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/) authenticated
- [just](https://github.com/casey/just) installed
- SSH key registered with DigitalOcean
- Claude Code authenticated locally (`claude login`)

## Setup

```bash
cp .env.example .env
# Edit .env with your DigitalOcean API token
```

## Deploy

```bash
just deploy        # Create droplet, run ansible playbook
just auth          # Transfer Claude Max credentials to the droplet
just onboard       # Interactive: openclaw onboard wizard
just tunnel        # SSH tunnel for dashboard at http://127.0.0.1:18789
```

## Tear down and rebuild

```bash
just destroy && just deploy
```

## All commands

```
just deploy      Create droplet and run ansible playbook
just destroy     Destroy droplet and firewall
just plan        Preview what will be created
just auth        Transfer local Claude credentials to the droplet
just onboard     Run openclaw onboard wizard (interactive)
just secure      Apply security hardening to openclaw.json
just ssh         SSH into the droplet as openclaw
just tunnel      SSH tunnel for dashboard (http://127.0.0.1:18789)
just status      Check services and setup status
just logs        Tail OpenClaw gateway logs
just snapshot    Create a DO snapshot
```

## Architecture

See [Init.md](Init.md) for the full spec.
