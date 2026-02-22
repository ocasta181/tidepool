#!/usr/bin/env bash
source "$(dirname "$0")/config.sh"

remote 'sudo journalctl -u openclaw -f --no-pager'
