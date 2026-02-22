# OpenClaw on DigitalOcean
#
# Setup:
#   1. Copy .env.example to .env and fill in your DO token
#   2. make init          (one-time)
#   3. make deploy        (creates droplet, runs ansible)
#   4. make auth          (transfers Claude Max credentials)
#   5. make onboard       (interactive: openclaw onboard)
#   6. make tunnel        (access dashboard at http://127.0.0.1:18789)
#
# Tear down and rebuild:
#   make destroy && make deploy

TF_DIR := terraform
SHELL  := /bin/bash

# Load .env if it exists
ifneq (,$(wildcard .env))
  include .env
  export
endif

IP = $(shell cd $(TF_DIR) && terraform output -raw droplet_ip 2>/dev/null)

.PHONY: help init plan deploy destroy status ssh tunnel auth onboard logs snapshot

help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

# --- Infrastructure ---

init: ## Initialize Terraform (run once)
	cd $(TF_DIR) && terraform init

plan: ## Preview infrastructure changes
	cd $(TF_DIR) && terraform plan

deploy: ## Create droplet and run ansible playbook
	cd $(TF_DIR) && terraform apply
	@echo ""
	@echo "Droplet deployed at $(IP)"
	@echo ""
	@echo "Next steps:"
	@echo "  make auth      Transfer Claude Max credentials"
	@echo "  make onboard   Run OpenClaw onboarding wizard"
	@echo "  make tunnel    Access the dashboard"

destroy: ## Destroy all infrastructure
	cd $(TF_DIR) && terraform destroy

# --- Post-deploy ---

auth: ## Transfer local Claude credentials to the droplet
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	@test -d "$$HOME/.claude" || (echo "No ~/.claude directory. Run 'claude login' locally first." && exit 1)
	@echo "Transferring ~/.claude/ to openclaw@$(IP)..."
	ssh openclaw@$(IP) 'mkdir -p ~/.claude && chmod 700 ~/.claude'
	scp -r $$HOME/.claude/* openclaw@$(IP):~/.claude/
	ssh openclaw@$(IP) 'chmod 600 ~/.claude/* 2>/dev/null; echo "Credentials transferred."'
	@echo ""
	@echo "Verifying claude is accessible..."
	ssh openclaw@$(IP) 'claude --version 2>/dev/null && echo "Claude CLI OK" || echo "WARNING: claude command not found in PATH"'
	@echo ""
	@echo "Next: make onboard"

onboard: ## SSH in and run openclaw onboard (interactive)
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	@echo "Launching interactive onboarding on the droplet..."
	@echo "When prompted:"
	@echo "  Provider:   Anthropic"
	@echo "  Auth:       setup-token (run 'claude setup-token' in another terminal)"
	@echo "  Model:      claude-opus-4-5"
	@echo "  Channel:    Telegram (provide BotFather token)"
	@echo ""
	ssh -t openclaw@$(IP) 'openclaw onboard --install-daemon'

secure: ## Apply security hardening to openclaw.json
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	@echo "Applying security configuration..."
	ssh openclaw@$(IP) 'bash -s' < scripts/apply-security.sh
	@echo "Running security audit..."
	ssh openclaw@$(IP) 'openclaw security audit --deep 2>/dev/null || echo "Security audit command not available yet"'
	ssh openclaw@$(IP) 'openclaw doctor 2>/dev/null || echo "Doctor command not available yet"'

# --- Daily use ---

ssh: ## SSH into the droplet as openclaw
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	ssh openclaw@$(IP)

tunnel: ## SSH tunnel for dashboard (http://127.0.0.1:18789)
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	@echo "Dashboard: http://127.0.0.1:18789"
	@echo "Press Ctrl+C to close."
	ssh -L 18789:127.0.0.1:18789 openclaw@$(IP)

status: ## Check services and setup status on the droplet
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	ssh openclaw@$(IP) '\
		echo "=== Services ===" && \
		systemctl is-active openclaw 2>/dev/null && echo "openclaw: running" || echo "openclaw: not running" && \
		echo "" && \
		echo "=== Docker ===" && \
		docker --version 2>/dev/null || echo "not installed" && \
		echo "" && \
		echo "=== Node ===" && \
		node --version 2>/dev/null || echo "not in PATH" && \
		echo "" && \
		echo "=== OpenClaw ===" && \
		openclaw --version 2>/dev/null || echo "not in PATH" && \
		echo "" && \
		echo "=== Tailscale ===" && \
		sudo tailscale status 2>/dev/null || echo "not connected" && \
		echo "" && \
		echo "=== Firewall ===" && \
		sudo ufw status 2>/dev/null | head -5'

logs: ## Tail OpenClaw gateway logs
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	ssh openclaw@$(IP) 'sudo journalctl -u openclaw -f --no-pager'

snapshot: ## Create a DO snapshot of the droplet
	@test -n "$(IP)" || (echo "No droplet. Run 'make deploy' first." && exit 1)
	$(eval DROPLET_ID := $(shell cd $(TF_DIR) && terraform output -raw droplet_id))
	doctl compute droplet-action snapshot $(DROPLET_ID) --snapshot-name "openclaw-$$(date +%Y%m%d-%H%M)"
