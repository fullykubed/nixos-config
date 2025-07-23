#!/usr/bin/env bash

# Does fuzzy matching for process killing

set -o pipefail

SIGNAL="${1:-15}" #Default: SIGTERM

ps -ef | fzf -m --preview-window=wrap | tr -s " " | cut -d" " -f2 | xargs -r kill -''"$SIGNAL"