#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

IP=$(require_droplet)
ssh "${OPENCLAW_USER}@${IP}"
