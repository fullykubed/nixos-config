#!/usr/bin/env bash

# For capturing jpeg screenshots

set -o pipefail

file=$1

if [[ -n $file ]]; then
  grimshot save area - | convert png:- jpg:"$file"
else
  grimshot save area - | convert png:- jpg:- | wl-copy
fi
