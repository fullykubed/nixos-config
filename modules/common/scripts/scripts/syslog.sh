#!/usr/bin/env bash

set -o pipefail

BOOT_NUM="${1:-0}"

journalctl -b "$BOOT_NUM" -n all -o json -f | lnav