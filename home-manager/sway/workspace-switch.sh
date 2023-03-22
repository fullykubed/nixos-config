#!/usr/bin/env bash

IFS=$'\n'

#################################################
# Step 1: Get the options
##################################################
columns=0
lines=0
str=""
workspaces=($(swaymsg -t get_workspaces -r | jq -r -c '.[] | .name'))
for workspace in "${workspaces[@]}"; do
    if [[ ${#workspace} -gt $columns ]];
    then
        columns=${#workspace}
    fi
    lines=$((lines+1))
    str="$str$workspace\n"
done

#################################################
# Step 2: Open an fzf modcal to prompt for selection
##################################################
prompt="Workspace> "
header="Switch to which workspace?"

# We save the selection in a temp file as the selection is done in another
# terminal
selection_file=/tmp/sway-workplace-switch-selection_file
trap 'rm -f $selection_file' EXIT

# Pretty formatting
lines=$((lines+3))
columns=$((columns+"${#header}"+5))
if [[ columns -gt 100 ]];
then
    columns=100
fi

alacritty \
  -o window.dimensions.columns=$columns \
  -o window.dimensions.lines=$lines \
  -o font.size=16.0 \
  -o window.padding.x=20 \
  -o window.padding.y=20 \
  --title "fzf-switcher" \
  -e bash -c "printf '$str' | fzf --header='$header' --prompt='$prompt' > $selection_file"

#################################################
# Step 3: Retrieve the selection and switch workspaces
##################################################
selection=$(cat $selection_file)
if [[ -n $selection ]]; then
    swaymsg workspace "$selection"
fi


