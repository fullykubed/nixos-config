#!/usr/bin/env sh

# Get the focused output from Sway
focused_output=$(swaymsg -t get_outputs | jaq -r 'map(select(.focused))[0].name')

# Get the list of all outputs from Sway
all_outputs=$(swaymsg -t get_outputs | jaq -r '.[].name')

# Iterate over each output
for output in $all_outputs; do
	# Check if the output is not the focused one
	if [[ "$output" != "$focused_output" ]]; then
		# Toggle the power state of the output
		swaymsg output "$output" toggle
	fi
done
