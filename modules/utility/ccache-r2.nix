# Shared ccache-R2 configuration: s3fs mount, s5cmd sync, tmpfiles, sandbox paths
#
# Used by both local machines (modules/common/ccache/) and remote builders
# (images/builder/image.nix). Consumers set credential paths, service
# ordering, and credential-wait behavior via the ccacheR2 options.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ccacheR2;

  r2Endpoint = "https://f875b3b102f2a88a51db200ba95e1fc9.r2.cloudflarestorage.com";
  r2Bucket = "ccache";
  ccacheDir = "/var/cache/ccache";
  r2MountDir = "/var/cache/ccache-r2";
  r2LocalDir = "/var/cache/ccache-r2-local";

  credentialWaitSnippet = ''
    while [ ! -f "${cfg.accessKeyFile}" ] || [ ! -f "${cfg.secretKeyFile}" ]; do
      echo "Waiting for R2 credentials..."
      sleep 5
    done
  '';
in
{
  options.ccacheR2 = {
    accessKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the R2 access key file.";
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to the R2 secret key file.";
    };

    afterServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Systemd units to order mount and sync services after.";
    };

    waitForCredentials = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to poll for credential files in preStart (for cloud-init).";
    };
  };

  config = {
    programs.fuse.userAllowOther = true;

    environment.systemPackages = with pkgs; [
      ccache
      s5cmd
      s3fs
    ];

    nix.settings.extra-sandbox-paths = [
      ccacheDir
      "${r2LocalDir}?"
      "${r2MountDir}?"
    ];

    systemd = {
      tmpfiles.rules = [
        "d ${ccacheDir} 0775 root nixbld -"
        "d ${r2MountDir} 0775 root nixbld -"
        "d ${r2LocalDir} 0775 root nixbld -"
      ];

      services.ccache-r2-mount = {
        description = "Mount R2 bucket as ccache directory via s3fs-fuse";
        after = cfg.afterServices ++ [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "10s";
        };
        path = [ pkgs.s3fs ];
        preStart = ''
          ${lib.optionalString cfg.waitForCredentials credentialWaitSnippet}
          mkdir -p ${r2MountDir}
          chown root:nixbld ${r2MountDir}
          chmod 0775 ${r2MountDir}
          ACCESS_KEY=$(cat ${cfg.accessKeyFile})
          SECRET_KEY=$(cat ${cfg.secretKeyFile})
          printf '%s:%s\n' "$ACCESS_KEY" "$SECRET_KEY" > /run/s3fs-credentials
          chmod 0400 /run/s3fs-credentials
        '';
        script = ''
          s3fs ${r2Bucket} ${r2MountDir} \
            -o passwd_file=/run/s3fs-credentials \
            -o url=${r2Endpoint} \
            -o use_path_request_style \
            -o endpoint=auto \
            -o allow_other \
            -o umask=0002 \
            -o gid=${toString config.users.groups.nixbld.gid} \
            -o complement_stat \
            -o max_stat_cache_size=2000000 \
            -o check_cache_dir_exist \
            -o listobjectsv2 \
            -o no_time_stamp_msg \
            -o connect_timeout=5 \
            -o readwrite_timeout=60 \
            -f \
            2> >(${pkgs.gnugrep}/bin/grep -v 'parser error' >&2)
        '';
      };

      services.ccache-r2-sync = {
        description = "Push new ccache entries from local dir to R2";
        after = cfg.afterServices ++ [ "network-online.target" ];
        wants = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "5min";
        };
        startLimitIntervalSec = 0;
        path = with pkgs; [
          s5cmd
          coreutils
          findutils
        ];
        script = ''
          set -euo pipefail

          ${lib.optionalString cfg.waitForCredentials credentialWaitSnippet}

          export AWS_ACCESS_KEY_ID=$(cat ${cfg.accessKeyFile})
          export AWS_SECRET_ACCESS_KEY=$(cat ${cfg.secretKeyFile})

          LOCAL="${r2LocalDir}"

          mapfile -t files < <(find "$LOCAL" -type f)
          [ ''${#files[@]} -eq 0 ] && exit 0

          # Upload all files to R2 in parallel
          for f in "''${files[@]}"; do
            rel="''${f#$LOCAL/}"
            printf 'cp "%s" "s3://${r2Bucket}/%s"\n' "$f" "$rel"
          done | s5cmd --endpoint-url "${r2Endpoint}" run

          # Delete uploaded files and clean up empty subdirs
          rm -f "''${files[@]}"
          find "$LOCAL" -mindepth 1 -type d -empty -delete 2>/dev/null || true
        '';
      };

      timers.ccache-r2-sync = {
        description = "Periodic trigger for ccache R2 sync";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "60s";
        };
      };
    };
  };
}
