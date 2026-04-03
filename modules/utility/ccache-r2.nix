# Shared ccache-R2 configuration: s5cmd download sync, s5cmd upload sync, tmpfiles, sandbox paths
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
  r2DownloadDir = "/var/cache/ccache-r2-download";
  r2UploadDir = "/var/cache/ccache-r2-upload";

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
  #   locale              - LANG/LC_* may differ between sandbox runs; only affects warning text, not compiled output
  #
  # NOT included (correctness risks outweigh hit-rate gains):
  #   system_headers      - in Nix, header store paths change when content changes; skipping them can return
  #                         objects compiled against old headers, producing subtly broken binaries
  ccacheConfig = pkgs.writeText "ccache.conf" ''
    remote_storage = file:///var/cache/ccache-r2-upload|umask=002|layout=subdirs file:///var/cache/ccache-r2-download|read-only|umask=002|layout=subdirs
    sloppiness = include_file_ctime,include_file_mtime,random_seed,time_macros,locale
    base_dir = /build
    max_size = ${cfg.maxSize}
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

    maxSize = lib.mkOption {
      type = lib.types.str;
      default = "200G";
      description = "Maximum size of the local ccache directory.";
    };

    downloadMaxSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Maximum size of the download directory (e.g. \"100G\"). When exceeded after sync, oldest files are evicted until the directory is 80% of this limit. Null disables eviction.";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      ccache
      s5cmd
    ];

    nix.settings.extra-sandbox-paths = [
      ccacheDir
      "${r2UploadDir}?"
      "${r2DownloadDir}?"
    ];

    systemd = {
      tmpfiles.rules = [
        "d ${ccacheDir} 0775 root nixbld -"
        "d ${r2DownloadDir} 0775 root nixbld -"
        "d ${r2UploadDir} 0775 root nixbld -"
        "C ${ccacheDir}/ccache.conf 0644 root nixbld - ${ccacheConfig}"
      ];

      services.ccache-r2-download = {
        description = "Sync R2 ccache bucket to local directory via s5cmd";
        after = cfg.afterServices ++ [ "network-online.target" ];
        wants = [ "network-online.target" ];
        restartIfChanged = false;
        serviceConfig = {
          Type = "oneshot";
          Restart = "on-failure";
          RestartSec = "5min";
        };
        startLimitIntervalSec = 0;
        path = with pkgs; [
          s5cmd
          coreutils
          bfs
        ];
        script = ''
          set -euo pipefail

          ${lib.optionalString cfg.waitForCredentials credentialWaitSnippet}

          export AWS_ACCESS_KEY_ID=$(cat ${cfg.accessKeyFile})
          export AWS_SECRET_ACCESS_KEY=$(cat ${cfg.secretKeyFile})

          s5cmd --endpoint-url "${r2Endpoint}" sync "s3://${r2Bucket}/*" "${r2DownloadDir}/"

          ${lib.optionalString (cfg.downloadMaxSize != null) ''
            MAX_BYTES=$(numfmt --from=iec "${cfg.downloadMaxSize}")
            TARGET_BYTES=$((MAX_BYTES * 80 / 100))
            CURRENT_BYTES=$(du -sb "${r2DownloadDir}" | cut -f1)

            if [ "$CURRENT_BYTES" -gt "$MAX_BYTES" ]; then
              echo "Download dir $(numfmt --to=iec "$CURRENT_BYTES") exceeds ${cfg.downloadMaxSize}, evicting oldest files..."
              while IFS=$'\t' read -r _mtime size path; do
                rm -f "$path"
                CURRENT_BYTES=$((CURRENT_BYTES - size))
                if [ "$CURRENT_BYTES" -le "$TARGET_BYTES" ]; then
                  break
                fi
              done < <(bfs "${r2DownloadDir}" -type f -printf '%T@\t%s\t%p\n' | sort -n)
              bfs "${r2DownloadDir}" -mindepth 1 -type d -empty -delete 2>/dev/null || true
              echo "Download dir now $(du -sh "${r2DownloadDir}" | cut -f1)"
            fi
          ''}
        '';
      };

      timers.ccache-r2-download = {
        description = "Periodic trigger for ccache R2 download sync";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "30min";
          RandomizedDelaySec = "10min";
        };
      };

      services.ccache-r2-upload = {
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
          bfs
        ];
        script = ''
          set -euo pipefail

          ${lib.optionalString cfg.waitForCredentials credentialWaitSnippet}

          export AWS_ACCESS_KEY_ID=$(cat ${cfg.accessKeyFile})
          export AWS_SECRET_ACCESS_KEY=$(cat ${cfg.secretKeyFile})

          LOCAL="${r2UploadDir}"

          mapfile -t files < <(bfs "$LOCAL" -type f)
          [ ''${#files[@]} -eq 0 ] && exit 0

          # Upload all files to R2 in parallel
          for f in "''${files[@]}"; do
            rel="''${f#$LOCAL/}"
            printf 'cp "%s" "s3://${r2Bucket}/%s"\n' "$f" "$rel"
          done | s5cmd --endpoint-url "${r2Endpoint}" run

          # Delete uploaded files and clean up empty subdirs
          rm -f "''${files[@]}"
          bfs "$LOCAL" -mindepth 1 -type d -empty -delete 2>/dev/null || true
        '';
      };

      timers.ccache-r2-upload = {
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
