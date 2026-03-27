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

  # ccache reads $CCACHE_DIR/ccache.conf automatically. Keeping these settings
  # in a config file instead of derivation env vars means changing tuning
  # parameters no longer invalidates every derivation hash.
  #
  # compiler_check is set to "%compiler% -dumpversion" rather than the default
  # "mtime". The default hashes the compiler's mtime and size, which changes on
  # every nixpkgs update even when GCC itself is identical, invalidating the
  # entire cache. The version-based check keeps entries valid across nixpkgs
  # updates that don't bump GCC.
  # RISK: if GCC is rebuilt with different patches but the same version number,
  # stale cached objects could be returned. Clear the cache after applying GCC
  # security patches.
  #
  # Sloppiness flags (each relaxes a check to improve hit rate in the sandbox):
  #   include_file_ctime  - sandbox copies/links sources, giving them fresh ctimes; without this ccache skips caching
  #   include_file_mtime  - generated headers during build get current mtime, same problem as ctime
  #   random_seed         - nixpkgs passes -frandom-seed which varies per derivation; ignore for cross-build hits
  #   time_macros         - ignore __DATE__/__TIME__/__TIMESTAMP__/SOURCE_DATE_EPOCH so timestamps don't bust cache
  #   system_headers      - system headers change store paths on nixpkgs updates even when byte-identical; skip in manifests
  #   locale              - LANG/LC_* may differ between sandbox runs; only affects warning text, not compiled output
  ccacheConfig = pkgs.writeText "ccache.conf" ''
    remote_storage = file:///var/cache/ccache-r2-local|umask=002|layout=subdirs file:///var/cache/ccache-r2|read-only|umask=002|layout=subdirs
    sloppiness = include_file_ctime,include_file_mtime,random_seed,time_macros,system_headers,locale
    base_dir = /build
    max_size = 200G
    compress = true
    compression_level = 3
    compiler_check = %compiler% -dumpversion
    hash_dir = false
    umask = 002
  '';

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
        "C+ ${ccacheDir}/ccache.conf 0644 root nixbld - ${ccacheConfig}"
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
