{ ... }:
{
  # Dynamic Hetzner Builders - Image Configuration
  #
  # This directory contains ONLY the NixOS configuration for the builder image
  # that gets uploaded to Hetzner Cloud as a snapshot.
  #
  # Directory structure:
  # - default.nix            : This file (builder image entry point)
  # - image.nix              : Complete NixOS system configuration
  # - hardware.nix           : Hetzner CCX hardware configuration
  # - inactivity-monitor.nix : Auto-shutdown service
  #
  # NOTE: Local machine integration (CLI tools, SSH config, waybar) lives
  # in modules/common/remote-builders/ and modules/common/scripts/

  imports = [
    ./image.nix
  ];
}
