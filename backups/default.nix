{ config, pkgs, lib, ... }:
let
  systemdUtil = import ../util/systemd.nix;

  # Main backup directives
  datasets = [
   { source = "primary/home"; backup = "secondary/encrypted/backups/home"; }
   { source = "primary/root"; backup = "secondary/encrypted/backups/root"; }
  ];

  # Backup configuration
  createTemplateCfg = template: dataset: ''
    [${dataset}]
      use_template = ${template}
  '';
  sanoidCfg = ''
    ${lib.strings.concatStringsSep "\n" (map (createTemplateCfg "source") sourceDatasets)}
    ${lib.strings.concatStringsSep "\n" (map (createTemplateCfg "backup") backupDatasets)}
    [template_source]
      autosnap = yes
      autoprune = yes
      frequently = 15
      frequent_period = 1
      hourly = 1
      daily = 7
      monthly = 6
      yearly = 0
    [template_backup]
      autosnap = no
      autoprune = yes
      frequently = 5
      frequent_period = 1
      hourly = 24
      daily = 90
      monthly = 24
      yearly = 10
  '';

  # Computed dataset properties
  sourceDatasets = map (ds: ds.source) datasets;
  backupDatasets = map (ds: ds.backup) datasets;
  backupRoots = with lib; map (str: strings.concatStringsSep "/" (lists.init (strings.splitString "/" str))) backupDatasets;
  datasetList = sourceDatasets ++ backupDatasets;

  # Function to build "zfs allow" and "zfs unallow" commands for the
  # filesystems we've delegated permissions to.
  buildZFSAllowCommand = user: zfsAction: permissions: dataset: lib.escapeShellArgs [
    # Here we explicitly use the booted system to guarantee the stable API needed by ZFS
    "+-/run/booted-system/sw/bin/zfs"
    zfsAction
    user
    (lib.strings.concatStringsSep "," permissions)
    dataset
  ];

  buildSyncoidCommand = {source, backup}: lib.escapeShellArgs ([
    "${pkgs.sanoid}/bin/syncoid"
    "--no-resume"
    "--no-privilege-elevation"
    "--no-sync-snap"
    "--quiet"
    source
    backup
  ]);

  # Common configuration between sanoid and syncoid
  buildServiceConfig = user: overrides@{...}: systemdUtil.buildSecureServiceConfig {
    Type = "oneshot";
    User = user;
    Group = user;
    RuntimeDirectory = user;
    CacheDirectory = user;
    PrivateDevices = "no"; # Need access to the devices for zfs management
    DeviceAllow = "/dev/zfs"; # Whitelist only particular devices
    ProtectProc = "default"; # Needed by zfs
    ProcSubset = "all"; # Needed by zfs
    ProtectHostname = "no"; # Needed by zfs
    ProtectClock = "no"; # Needed by zfs
    KillMode = "process";
    KillSignal = "SIGINT";
  } // overrides;
in
{
  # Make this globally available
  environment.systemPackages = with pkgs; [ sanoid ];

  # Snaphots
  systemd.services.sanoid = {
    description = "Sanoid ZFS backups";
    enable = true;
    startLimitBurst = 3;
    startLimitIntervalSec = 15;
    startAt = "*-*-* *:*:00";
    after = [ "zfs.target" ];
    environment = {
      TZ = "UTC";
    };
    serviceConfig = buildServiceConfig "sanoid" {
      ExecStartPre = (map (buildZFSAllowCommand "sanoid" "allow" [ "snapshot" "mount" "destroy" ]) datasetList);
      ExecStart = lib.escapeShellArgs ([
        "${pkgs.sanoid}/bin/sanoid"
        "--cron"
        "--configdir"
        (pkgs.writeTextDir "sanoid.conf" sanoidCfg)
      ]);
      ExecStopPost = (map (buildZFSAllowCommand "sanoid" "unallow" [ "snapshot" "mount" "destroy" ]) datasetList);
    };
  };

  # Pool syncing
  systemd.services.syncoid = {
    description = "Syncoid ZFS backup syncs";
    enable = true;
    startLimitBurst = 3;
    startLimitIntervalSec = 15;
    startAt = "*-*-* *:0/5:00";
    after = [ "zfs.target" ];
    environment = {
      TZ = "UTC";
    };
    serviceConfig = buildServiceConfig "syncoid" {
      ExecStartPre = (map (buildZFSAllowCommand "syncoid" "allow" [ "send" "hold" ]) sourceDatasets) ++
        (map (buildZFSAllowCommand "syncoid" "allow" [ "create" "mount" "receive" "hold" "rollback" ]) backupRoots);
      ExecStart = map buildSyncoidCommand datasets;
      ExecStopPost = (map (buildZFSAllowCommand "syncoid" "unallow" [ "send" "hold" ]) sourceDatasets) ++
        (map (buildZFSAllowCommand "syncoid" "unallow" [ "create" "mount" "receive" "hold" "rollback" ]) backupRoots);
    };
  };
}