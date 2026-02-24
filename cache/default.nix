{ ... }:
{
  # niks3 Binary Cache Server - Image Configuration
  #
  # This directory contains ONLY the NixOS configuration for the cache server
  # image that gets uploaded to Hetzner Cloud as a snapshot.
  #
  # Directory structure:
  # - default.nix            : This file (cache server entry point)
  # - image.nix              : Complete NixOS system configuration
  # - hardware.nix           : Hetzner Cloud hardware configuration
  #
  # The cache server runs niks3 (S3-backed binary cache) with PostgreSQL.
  # It is a persistent server (no auto-shutdown).

  imports = [
    ./image.nix
  ];
}
