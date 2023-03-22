#!/usr/bin/env bash

# Copy the local system configuration project to the OS etc directory;
# Change ownership to root
sudo rsync \
  -r \
  -p \
  --usermap=jack:root \
  --exclude=.idea \
  --exclude=.git \
  "$(realpath "$(dirname "$0")")/" /etc/nixos

if [[ $1 == "boot" ]]; then
  sudo nixos-rebuild boot
else
  # Initiate a quick rebuild of the project
  sudo nixos-rebuild switch --fast
fi

