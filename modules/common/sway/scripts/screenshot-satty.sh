#!/usr/bin/env bash

# Capture screenshot of selected area and send to satty
# Satty will copy to clipboard when Enter is pressed

# Capture area screenshot, pipe to satty, then to clipboard
grim -g "$(slurp -c '#ff0000ff')" - | \
satty --filename - --output-filename - --early-exit | \
wl-copy -t image/png