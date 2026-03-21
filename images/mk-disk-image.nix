# Shared disk image builder for Hetzner Cloud VMs
# Each image directory calls this with its specific modules and disk size.
{ nixpkgs, determinate }:
{
  modules,
  additionalSpace,
}:
let
  cacheModule = import ../modules/utility/cache-module.nix;
  casModule = import ../modules/utility/cas-module.nix;
  nixSettingsModule = import ../modules/utility/nix-settings.nix;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  system = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      cacheModule
      casModule
      nixSettingsModule
      determinate.nixosModules.default
      {
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };
      }
    ]
    ++ modules;
  };
in
pkgs.callPackage "${nixpkgs}/nixos/lib/make-disk-image.nix" {
  inherit pkgs additionalSpace;
  inherit (pkgs) lib;
  inherit (system) config;
  format = "raw";
  diskSize = "auto";
  partitionTableType = "efi";
  copyChannel = false;
  label = "nixos";
  postVM = ''
    ${pkgs.zstd}/bin/zstd -6 --rm -f $diskImage -o $out/nixos.img.zst
  '';
}
