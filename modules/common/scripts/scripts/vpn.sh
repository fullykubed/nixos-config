#!/usr/bin/env bash

# mnemonic: VPN management through wg-quick
# Quick way to start/stop a wireguard connection

set -o pipefail

COMMAND=${1:-'up'}

CONF_DIR=$HOME/wireguard
CONF_FILE="$(find "$CONF_DIR" -name "*.conf" -printf "%f\n" | fzf)"
wg-quick "$COMMAND" "$CONF_DIR/$CONF_FILE"