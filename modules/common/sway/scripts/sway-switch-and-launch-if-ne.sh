#!/usr/bin/env bash

# This script takes a workspace and a grep query string. It switches to the workspace and
# checks to see if the workspace has any windows with an app_id matching the query string.
# If not, it will execute the remaining arguments as a command.

set -o pipefail

WORKSPACE=$1
GREP_QUERY=$2

# Switch to the workspace
swaymsg workspace "$WORKSPACE"

# If the workspace does not have a window with a title matching the grep query, execute command
swaymsg -t get_workspaces -r | jaq -r '.[] | select(.focused == true).representation' | grep -q "$GREP_QUERY"
if [[ $? == 0 ]]; then
	exit 0
else
	${@:3}
fi
