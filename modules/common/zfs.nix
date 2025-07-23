# See https://nixos.wiki/wiki/OBS_Studio

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{

  # ZFS support for podman
  virtualisation.podman = {
    extraPackages = with pkgs; [ zfs ];
  };

  boot.kernelParams = [
    "nohibernate" # With ZFS we cannot hibernate (also poses a security issue due to RAM persistence)
    "zfs.zfs_max_recordsize=16777216" # Allow large 16M record sizes
    "zfs.zfs_dirty_data_max_percent=50" # Allows 50% of RAM to be consumed by writes before throttling
    "zfs.zfs_dirty_data_sync=1073741824" # Allows 1GiB of data to accumulate before forcing a disk sync more often than 5 sec interval
  ];

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  boot.extraModprobeConfig = ''
    options zfs l2arc_rebuild_enabled=1 l2arc_headroom=0 l2arc_write_max=${
      builtins.toString (100 * 1024 * 1024)
    } l2arc_write_boost=${builtins.toString (1024 * 1024 * 1024)} l2arc_noprefetch=0
  '';

  age = {
    secrets = {
      pushover-token = {
        rekeyFile = ../../secrets/pushover-token.age;
      };
    };
  };

  # Disk notifications
  services.zfs.zed = {
    settings = {
      # TODO: Figure out how to move this to a secrets file
      ZED_PUSHOVER_TOKEN = "REDACTED_PUSHOVER_TOKEN"; # builtins.readFile config.age.screts./nix/store/92qgxh12m6xvz0w4yx41zmzzc6bv5dmc-zfs-user-2.3.3/etc/default/zfs;
      ZED_PUSHOVER_USER = "ubeszsjqr12emacca1wgqgca5g3yau";
    };
  };

  home-manager.users.${config.username} = {
    # Custom scripts for debugging zfs issues
    home.shellAliases = {
      # For monitoring disk usage
      zio = "watch -n 1 zpool iostat -lvy 1 1";

      # For checking stats on a zfs pool
      zstat = "sudo zpool status -v";

      # For checkings block stats on a zfs dataset
      zblock = "sudo zdb -bbb";
    };
  };

}
