# See https://nixos.wiki/wiki/OBS_Studio

{
  config,
  lib,
  pkgs,
  ...
}:
let
  pushover-user = "ubeszsjqr12emacca1wgqgca5g3yau";
  zed-test = pkgs.writeScriptBin "zed-test" ''
    #!/usr/bin/env bash
    # Test ZED Pushover notification

    # Set up ZED environment
    export ZED_ZEDLET_DIR="/etc/zfs/zed.d"

    # Source the ZED functions (which should load our Pushover credentials)
    . /etc/zfs/zed.d/zed-functions.sh

    # Check if credentials are loaded
    if [ -z "$ZED_PUSHOVER_TOKEN" ] || [ -z "$ZED_PUSHOVER_USER" ]; then
        echo "ERROR: Pushover credentials not loaded!"
        echo "Token: ''${ZED_PUSHOVER_TOKEN:-not set}"
        echo "User: ''${ZED_PUSHOVER_USER:-not set}"
        exit 1
    fi

    echo "Pushover credentials loaded successfully"
    echo "Sending test notification..."

    # Create a test message
    subject="ZED Test Notification"
    message="This is a test notification from ZED on $(hostname) at $(date)"

    # Create temporary file for message
    tmpfile=$(mktemp)
    echo "$message" > "$tmpfile"

    # Send the notification using ZED's pushover function
    zed_notify_pushover "$subject" "$tmpfile"
    result=$?

    # Clean up
    rm -f "$tmpfile"

    if [ $result -eq 0 ]; then
        echo "✓ Notification sent successfully!"
    else
        echo "✗ Failed to send notification (exit code: $result)"
    fi

    exit $result
  '';
in
{
  boot = {
    zfs = {
      package = pkgs.zfs_2_4;
      forceImportAll = false;
      requestEncryptionCredentials = lib.mkDefault [ "rpool" ];
    };
    kernelParams = [
      "nohibernate" # With ZFS we cannot hibernate (also poses a security issue due to RAM persistence)
      "zfs.zfs_max_recordsize=16777216" # Allow large 16M record sizes
      "zfs.zfs_dirty_data_max_percent=50" # Allows 50% of RAM to be consumed by writes before throttling
      "zfs.zfs_dirty_data_sync=1073741824" # Allows 1GiB of data to accumulate before forcing a disk sync more often than 5 sec interval
    ];
    extraModprobeConfig = ''
      options zfs l2arc_rebuild_enabled=1 l2arc_headroom=0 l2arc_write_max=${
        builtins.toString (100 * 1024 * 1024)
      } l2arc_write_boost=${builtins.toString (1024 * 1024 * 1024)} l2arc_noprefetch=0
    '';
  };

  # ZFS support for podman
  virtualisation.podman = {
    extraPackages = [ config.boot.zfs.package ];
  };

  # Standard rpool layout — encryption at pool level, flat dataset names
  disko.devices.zpool.rpool = {
    type = "zpool";
    rootFsOptions = {
      mountpoint = "none";
      compression = "zstd";
      acltype = "posixacl";
      xattr = "sa";
      atime = "off";
      encryption = "aes-256-gcm";
      keyformat = "passphrase";
      keylocation = "prompt";
    };
    datasets = {
      "root" = {
        type = "zfs_fs";
        options.mountpoint = "legacy";
        mountpoint = "/";
      };
      "home" = {
        type = "zfs_fs";
        options.mountpoint = "legacy";
        mountpoint = "/home";
      };
      "nix" = {
        type = "zfs_fs";
        options.mountpoint = "legacy";
        mountpoint = "/nix";
      };
      "var/log" = {
        type = "zfs_fs";
        options.mountpoint = "legacy";
        mountpoint = "/var/log";
      };
      "tmp" = {
        type = "zfs_fs";
        options.mountpoint = "legacy";
        mountpoint = "/tmp";
      };
    };
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  age = {
    secrets = {
      pushover-token = {
        rekeyFile = ../../../secrets/pushover-token.age;
        owner = config.username;
        group = "users";
        mode = "0400";
      };
    };
  };

  # Disk notifications
  services.zfs.zed.settings = {
    ZED_PUSHOVER_USER = pushover-user;
  };

  # Override the zed-functions.sh to source our secret
  environment.etc."zfs/zed.d/zed-functions.sh" = {
    source = lib.mkForce (
      pkgs.runCommand "zed-functions-with-secret.sh" { } ''
        # Copy the original zed-functions.sh
        cp ${pkgs.zfs}/etc/zfs/zed.d/zed-functions.sh $out

        # Add a line after the shebang to source our secret token
        sed -i '2i\
        # Source Pushover token from agenix\
        if [ -f "${config.age.secrets.pushover-token.path}" ]; then\
          export ZED_PUSHOVER_TOKEN="$(cat ${config.age.secrets.pushover-token.path})"\
          export ZED_PUSHOVER_USER="${pushover-user}"\
        fi' $out
      ''
    );
  };

  # Create a test script for ZED notifications
  environment.systemPackages = [ zed-test ];

  home-manager.users.${config.username} = {
    # Custom scripts for debugging zfs issues
    programs.zsh.shellAliases = {
      # For monitoring disk usage
      zio = "watch -n 1 zpool iostat -lvy 1 1";

      # For checking stats on a zfs pool
      zstat = "doas zpool status -v";

      # For checkings block stats on a zfs dataset
      zblock = "doas zdb -bbb";
    };
  };

}
