# Hetzner Cloud CLI tools
{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: _prev: {
      hcloud-upload-image = final.callPackage ../../../lib/packages/hcloud-upload-image.nix { };
    })
  ];

  environment.systemPackages = [
    pkgs.hcloud
    pkgs.hcloud-upload-image
  ];
}
