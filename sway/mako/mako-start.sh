#!/bin/sh

# We need to use this hack to get the output name as mako does not allow us to use a static monitor name
output=$(swaymsg -t get_outputs -p | grep "$SWAY_NOTIFICATION_OUTPUT" | cut -d' ' -f2)

mako --output="$output"
