# Shared disk image builder for Hetzner Cloud VMs
# Each image directory calls this with its specific modules and disk size.
{ nixpkgs, determinate }:
{
  modules,
  additionalSpace,
}:
let
  casModule = import ../modules/utility/cas-module.nix;
  nixSettingsModule = import ../modules/utility/nix-settings.nix;
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  system = nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      casModule
      nixSettingsModule
      determinate.nixosModules.default
      {
        fileSystems."/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
          autoResize = true;
        };
        nix.gc.automatic = false;

        # The Determinate NixOS module redirects NixOS-generated nix.conf to
        # nix.custom.conf, then determinate-nixd writes the real nix.conf
        # (with !include nix.custom.conf) when the daemon starts.  But the
        # daemon is socket-activated, so on a fresh boot nix.conf doesn't
        # exist yet and the nix *client* falls back to built-in defaults.
        # Bootstrap a minimal nix.conf so settings are visible immediately;
        # determinate-nixd overwrites it with its full version on first use.
        systemd.tmpfiles.rules = [
          "f /etc/nix/nix.conf 0644 root root - !include /etc/nix/nix.custom.conf"
        ];
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
