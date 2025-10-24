{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gscan2pdf # Scanning GUI (uses global ImageMagick downgrade from flake.nix)
  ];
}