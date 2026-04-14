# Declarative Syncthing utility module
#
# Core logic for Syncthing configuration: NixOS options, device/folder registries,
# and assembled services.syncthing settings. Designed to work standalone without
# any common modules, Home Manager, or global options.
#
# The common wrapper at modules/common/syncthing/default.nix imports this module and
# wires config.username/homeDir into the options defined here, plus declares agenix
# secrets for the host's Syncthing key and certificate.
{
  config,
  lib,
  ...
}:
let
  cfg = config.syncthing;

  # ---------------------------------------------------------------------------
  # Central folder registry — all available folders across the fleet
  # ---------------------------------------------------------------------------
  folderRegistry = {
    keepass = {
      id = "keepass";
      label = "Keepass";
      pathTemplate = "${cfg.dataDir}/keepass";
    };
    pixel_camera = {
      id = "pixel_6_jgkv-photos";
      label = "S9_Camera";
      pathTemplate = "${cfg.dataDir}/camera/pixel";
      type = "receiveonly";
    };
  };

  # ---------------------------------------------------------------------------
  # NixOS managed devices — device IDs read from plaintext files
  # folders = the folders this device is expected to sync (duplicated here
  # because each host builds independently and cannot read other hosts' configs)
  # ---------------------------------------------------------------------------
  readDeviceId = path: lib.strings.trim (builtins.readFile path);

  nixosDevices = {
    "fullykubed-tower" = {
      id = readDeviceId ../../secrets/machines/fullykubed-tower/syncthing-device-id;
      folders = [
        "keepass"
      ];
    };
    "fullykubed-mini-pc" = {
      id = readDeviceId ../../secrets/machines/fullykubed-mini-pc/syncthing-device-id;
      folders = [
        "keepass"
        "pixel_camera"
      ];
    };
    "fullykubed-starfighter" = {
      id = readDeviceId ../../secrets/machines/fullykubed-starfighter/syncthing-device-id;
      folders = [
        "keepass"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # External (non-NixOS) devices — phones, Macs, etc.
  # Device IDs are hardcoded; folder memberships declared inline.
  # ---------------------------------------------------------------------------
  externalDevices = {
    "pixel6" = {
      id = "C475M4E-JGQ6PNA-PQD5WTV-OQRBRXW-AGQO6ZI-WS4JO6U-DSJR7OK-T2RWIQN";
      folders = [
        "keepass"
        "pixel_camera"
      ];
    };
    "macbook-pro" = {
      id = "ZXFSFRZ-TV3AZHA-AWMPGNN-GNNPY2P-UABF33O-AE2KH4U-CR6OKF4-2JPY4QU";
      folders = [
        "keepass"
      ];
    };
  };

  # ---------------------------------------------------------------------------
  # Peer device assembly
  # ---------------------------------------------------------------------------

  # All devices combined
  allDevices = nixosDevices // externalDevices;

  # Exclude the current host from the peer list
  peerDevices = lib.filterAttrs (name: _: name != config.networking.hostName) allDevices;

  # Build services.syncthing.settings.devices attrset (name -> { id })
  syncthingDevices = lib.mapAttrs (_: dev: { inherit (dev) id; }) peerDevices;

  # ---------------------------------------------------------------------------
  # Folder assembly helpers
  # ---------------------------------------------------------------------------

  # For a given folder name, collect all peer device names that sync it
  folderDevices =
    folderName:
    lib.filter (name: lib.elem folderName (peerDevices.${name}.folders or [ ])) (
      builtins.attrNames peerDevices
    );

  # Current host's folder list (looked up from device registries)
  myFolders = (allDevices.${config.networking.hostName} or { folders = [ ]; }).folders;

  # Build services.syncthing.settings.folders from the current host's membership
  # Only includes folders this host is a member of
  syncthingFolders = lib.listToAttrs (
    map (
      fname:
      let
        folder = folderRegistry.${fname};
      in
      lib.nameValuePair fname {
        inherit (folder) id label;
        path = folder.pathTemplate;
        devices = folderDevices fname;
        type = folder.type or "sendreceive";
      }
    ) myFolders
  );
in
{
  options.syncthing = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "User account under which the Syncthing service runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      description = "Group under which the Syncthing service runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Base directory for Syncthing data (home directory or equivalent).";
    };

  };

  config = {
    services.syncthing = {
      enable = true;
      inherit (cfg) user group dataDir;
      systemService = true;
      overrideDevices = true;
      overrideFolders = true;
      settings = {
        devices = syncthingDevices;
        folders = syncthingFolders;
      };
    };
  };
}
