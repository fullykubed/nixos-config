{
  self,
  lib,
  pkgs,
  modulesPath,
  targetMachine,
  ...
}:
let
  targetConfig = self.nixosConfigurations.${targetMachine}.config;
  toplevel = "${targetConfig.system.build.toplevel}";
  diskoScript = "${targetConfig.system.build.diskoScript}";
  targetDisks = lib.mapAttrsToList (_: d: d.device) targetConfig.disko.devices.disk;
in
{
  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
  ];

  # ZFS support for partitioning and installation
  boot.supportedFilesystems.zfs = true;

  # ISO image configuration
  image.baseName = lib.mkForce "fullykubed-installer-${self.shortRev or "dirty"}";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";

  isoImage = {
    # Include target machine closures so installation works offline
    storeContents = [
      targetConfig.system.build.toplevel
      targetConfig.system.build.diskoScript
    ];
  };

  users.motd = ''
    Run 'sudo install-machine' to begin installation.
  '';

  environment = {
    etc = {
      # Make the flake source tree available for copying to the target
      "installer/repo".source = self;
    };

    # Tools available in the installer environment
    systemPackages = [
      pkgs.openssl
      pkgs.pv
      (pkgs.writeScriptBin "install-machine" (
        builtins.replaceStrings
          [ "@machine@" "@toplevel@" "@diskoScript@" "@targetDisks@" "@cpuCount@" ]
          [
            targetMachine
            toplevel
            diskoScript
            (lib.concatMapStringsSep " " (d: ''"${d}"'') targetDisks)
            (toString targetConfig.cpuCount)
          ]
          (builtins.readFile ./install-machine.sh)
      ))
    ];
  };
}
