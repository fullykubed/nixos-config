{
  config,
  lib,
  pkgs,
  ...
}:
let
  # ---------------------------------------------------------------------------
  # Declarative builder inventory
  # ---------------------------------------------------------------------------
  # Each entry has a type ("cloud" or "bare-metal") plus per-builder config.
  # Cloud builders are provisioned on-demand via the Hetzner API.
  # Bare-metal builders are always-on; ensure-builder.sh only checks SSH
  # reachability for them (no Hetzner API calls).
  builderFleet = {
    builder-1 = {
      type = "cloud";
      tier = "regular";
      maxJobs = 20;
      speedFactor = 1;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../../secrets/builder-host-key.pub);
      serverType = "cpx62";
      fallbackServerType = "cpx52";
      mandatoryFeatures = [ ];
    };
    builder-2 = {
      type = "cloud";
      tier = "regular";
      maxJobs = 20;
      speedFactor = 1;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../../secrets/builder-host-key.pub);
      serverType = "cpx62";
      fallbackServerType = "cpx52";
      mandatoryFeatures = [ ];
    };
    big-builder-1 = {
      type = "cloud";
      tier = "big-parallel";
      maxJobs = 1;
      speedFactor = 1;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../../secrets/builder-host-key.pub);
      serverType = "ccx63";
      fallbackServerType = null;
      mandatoryFeatures = [ "big-parallel" ];
    };
    big-builder-2 = {
      type = "cloud";
      tier = "big-parallel";
      maxJobs = 1;
      speedFactor = 1;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../../secrets/builder-host-key.pub);
      serverType = "ccx63";
      fallbackServerType = null;
      mandatoryFeatures = [ "big-parallel" ];
    };
    big-builder-3 = {
      type = "cloud";
      tier = "big-parallel";
      maxJobs = 1;
      speedFactor = 1;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (builtins.readFile ../../../secrets/builder-host-key.pub);
      serverType = "ccx63";
      fallbackServerType = null;
      mandatoryFeatures = [ "big-parallel" ];
    };
    # Geekom IT15 NUC bare-metal builders (Intel Core Ultra 9 285H, 16 cores, 32 GB)
    # Always-on; ensure-builder.sh checks SSH reachability only (no Hetzner API)
    fullykubed-nuc-1 = {
      type = "bare-metal";
      tier = "regular";
      maxJobs = 14; # 14 isolated cores (builderIsolatedCpus = "2-15")
      speedFactor = 2; # Arrow Lake ~2x faster per core than cloud vCPUs
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (
        builtins.readFile ../../../secrets/machines/fullykubed-nuc-1/ssh-host-key.pub
      );
      serverType = null;
      fallbackServerType = null;
      mandatoryFeatures = [ ];
    };
    fullykubed-nuc-2 = {
      type = "bare-metal";
      tier = "regular";
      maxJobs = 14;
      speedFactor = 2;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (
        builtins.readFile ../../../secrets/machines/fullykubed-nuc-2/ssh-host-key.pub
      );
      serverType = null;
      fallbackServerType = null;
      mandatoryFeatures = [ ];
    };
    fullykubed-nuc-3 = {
      type = "bare-metal";
      tier = "regular";
      maxJobs = 14;
      speedFactor = 2;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (
        builtins.readFile ../../../secrets/machines/fullykubed-nuc-3/ssh-host-key.pub
      );
      serverType = null;
      fallbackServerType = null;
      mandatoryFeatures = [ ];
    };
    fullykubed-nuc-4 = {
      type = "bare-metal";
      tier = "regular";
      maxJobs = 14;
      speedFactor = 2;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (
        builtins.readFile ../../../secrets/machines/fullykubed-nuc-4/ssh-host-key.pub
      );
      serverType = null;
      fallbackServerType = null;
      mandatoryFeatures = [ ];
    };
    fullykubed-nuc-5 = {
      type = "bare-metal";
      tier = "regular";
      maxJobs = 14;
      speedFactor = 2;
      sshPort = 3098;
      hostPublicKey = lib.removeSuffix "\n" (
        builtins.readFile ../../../secrets/machines/fullykubed-nuc-5/ssh-host-key.pub
      );
      serverType = null;
      fallbackServerType = null;
      mandatoryFeatures = [ ];
    };
  };

  # ---------------------------------------------------------------------------
  # Derive nix.buildMachines entries from the fleet inventory
  # ---------------------------------------------------------------------------
  # NOTE: publicHostKey is intentionally omitted from all entries.
  # Nix creates known_hosts entries without port qualifiers, which fail
  # StrictHostKeyChecking on port 3098.  SSH falls back to the system-wide
  # UserKnownHostsFile (builderKnownHosts) which has correct [hostname]:port
  # entries.
  mkBuildMachine = name: cfg: {
    hostName = name;
    sshUser = "remotebuild";
    sshKey = "/root/.ssh/builder-key";
    system = "x86_64-linux";
    inherit (cfg) maxJobs speedFactor mandatoryFeatures;
    supportedFeatures = [
      "nixos-test"
      "kvm"
      "benchmark"
      "ca-derivations"
    ]
    ++ (if cfg.tier == "big-parallel" then [ "big-parallel" ] else [ ]);
  };

  buildMachines = lib.mapAttrsToList mkBuildMachine builderFleet;

  # ---------------------------------------------------------------------------
  # Known-hosts file: [hostname]:port entries for all builders
  # ---------------------------------------------------------------------------
  builderKnownHosts = pkgs.writeText "builder-known-hosts" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        name: cfg: "[${name}]:${toString cfg.sshPort} ${cfg.hostPublicKey}"
      ) builderFleet
    )
    + "\n"
  );

  # CLI tool for managing builders (defined first so proxy can use it).
  # builders-cli.sh contains a @remote_stats@ placeholder that is replaced at
  # eval time with the contents of remote-stats.sh via builtins.replaceStrings,
  # so both builders-cli and the builder-status service share the same
  # metrics-collection snippet without runtime path dependencies and without
  # requiring allow-import-from-derivation.
  buildersCliText =
    builtins.replaceStrings [ "@remote_stats@" ] [ (builtins.readFile ./remote-stats.sh) ]
      (builtins.readFile ./builders-cli.sh);

  # ---------------------------------------------------------------------------
  # Builder fleet JSON — written to /etc/builder-fleet.json so that
  # ensure-builder.sh can determine builder types without a Nix dependency.
  # ---------------------------------------------------------------------------
  builderFleetJson = pkgs.writeText "builder-fleet.json" (
    builtins.toJSON (
      lib.mapAttrs (_name: cfg: {
        inherit (cfg) type tier sshPort;
      }) builderFleet
    )
  );

  # ---------------------------------------------------------------------------
  # SSH Match block pattern: comma-separated list of all builder hostnames
  # ---------------------------------------------------------------------------
  allBuilderHostPattern = lib.concatStringsSep "," (lib.attrNames builderFleet);

  # ---------------------------------------------------------------------------
  # CLI tool for managing builders (defined first so proxy can use it)
  # ---------------------------------------------------------------------------
  buildersCli = pkgs.writeShellApplication {
    name = "builders";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.bc
      pkgs.iperf3
      pkgs.ncurses
      pkgs.curl
      pkgs.openssl
      pkgs.croc
      pkgs.netcat-gnu
      pkgs.tailscale
      pkgs.openssh
      pkgs.python3
      pkgs.util-linux
      pkgs.gnugrep
    ];
    text = buildersCliText;
  };

  # builder-status script: hcloud poll + SSH fanout + JSON merge.
  # builder-status.sh contains a @remote_stats@ placeholder substituted at
  # eval time with the contents of remote-stats.sh (same pattern as buildersCli).
  builderStatusScript = pkgs.writeShellApplication {
    name = "builder-status";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.openssh
      pkgs.tailscale
      pkgs.coreutils
      pkgs.util-linux
      pkgs.gnugrep
    ];
    text = builtins.replaceStrings [ "@remote_stats@" ] [ (builtins.readFile ./remote-stats.sh) ] (
      builtins.readFile ./builder-status.sh
    );
  };

  # ---------------------------------------------------------------------------
  # ensure-builder: SSH Match exec script that provisions builders on-demand
  # ---------------------------------------------------------------------------
  ensureBuilderScript = pkgs.writeShellApplication {
    name = "ensure-builder";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jaq
      pkgs.netcat-gnu
      pkgs.util-linux # flock
      buildersCli
    ];
    text = builtins.readFile ./ensure-builder.sh;
  };

  tokenPath = config.age.secrets.hetzner-api-token.path;

  # Wrappers that auto-load the Hetzner API token for interactive root use
  hcloudWrapped = pkgs.writeShellScriptBin "hcloud" ''
    export HCLOUD_TOKEN
    HCLOUD_TOKEN=$(cat ${tokenPath})
    exec ${pkgs.hcloud}/bin/hcloud "$@"
  '';
  hcloudUploadImageWrapped = pkgs.writeShellScriptBin "hcloud-upload-image" ''
    export HCLOUD_TOKEN
    HCLOUD_TOKEN=$(cat ${tokenPath})
    exec ${pkgs.hcloud-upload-image}/bin/hcloud-upload-image "$@"
  '';

  # ---------------------------------------------------------------------------
  # SSH Match block generators
  # ---------------------------------------------------------------------------
  # Cloud builders need the exec ensure-builder guard (provisions on demand).
  # Bare-metal builders still go through ensure-builder but it only checks SSH
  # reachability (no Hetzner API calls); the same binary handles both types by
  # reading /etc/builder-fleet.json.
  mkSshMatchBlock = hostPattern: ''
    Match host ${hostPattern} exec "${ensureBuilderScript}/bin/ensure-builder %h 3098"
      User remotebuild
      Port 3098
      IdentityFile /root/.ssh/builder-key
      IdentitiesOnly yes
      StrictHostKeyChecking yes
      UserKnownHostsFile ${builderKnownHosts}
      LogLevel ERROR
      ConnectTimeout 30
      Compression yes
      IPQoS cs1
  '';
in
{
  nix = {
    distributedBuilds = true;
    inherit buildMachines;
    settings.builders-use-substitutes = true;
  };

  environment = {
    systemPackages = [
      buildersCli
      pkgs.hcloud # Hetzner Cloud CLI
      pkgs.bc # Calculator for cost estimation
      pkgs.hcloud-upload-image # Upload custom images to Hetzner Cloud
    ];

    # Place the public keys alongside the private keys
    etc = {
      "builder-ssh-key.pub" = {
        source = ../../../secrets/builder-ssh-key.pub;
        target = "ssh/builder-key.pub";
        mode = "0444";
      };

      "builder-host-key.pub" = {
        source = ../../../secrets/builder-host-key.pub;
        target = "ssh/builder-host-key.pub";
        mode = "0444";
      };

      # Builder fleet JSON for ensure-builder.sh type dispatch
      "builder-fleet.json" = {
        source = builderFleetJson;
        mode = "0444";
      };
    };
  };

  # Token-injecting wrappers for interactive root use — these shadow the
  # unwrapped binaries in root's per-user profile so `sudo hcloud …` just works.
  home-manager.users.root.home.packages = [
    hcloudWrapped
    hcloudUploadImageWrapped
  ];

  # Secrets for Hetzner API and SSH authentication
  age.secrets = {
    hetzner-api-token = {
      rekeyFile = ../../../secrets/hetzner-api-token.age;
      mode = "0400";
      owner = "root";
    };
    builder-ssh-key = {
      rekeyFile = ../../../secrets/builder-ssh-key.age;
      path = "/root/.ssh/builder-key";
      mode = "0400";
      owner = "root";
    };
    builder-host-key = {
      rekeyFile = ../../../secrets/builder-host-key.age;
      path = "/run/agenix/builder-host-key";
      mode = "0400";
      owner = "root";
    };
  };

  # Systemd service that polls hcloud for builder status, SSHs to each running
  # builder to collect runtime metrics, and writes a merged JSON file to a
  # world-readable location so unprivileged processes (waybar) can read it.
  systemd.services.builder-status = {
    description = "Poll Hetzner Cloud for builder server status";
    restartIfChanged = false;
    reloadIfChanged = true;
    after = [
      "network-online.target"
      "nss-lookup.target"
      "tailscale-autoconnect.service"
    ];
    wants = [
      "network-online.target"
      "nss-lookup.target"
      "tailscale-autoconnect.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "builder-status";
      RuntimeDirectoryPreserve = "yes";
      EnvironmentFile = ""; # clear any inherited env
      # Skip (not fail) if DNS is not yet working — dnscrypt-proxy may be running
      # but unable to forward queries until the DHCP lease arrives. The timer
      # retries every 30s so a skipped run is harmless.
      ExecCondition = "${pkgs.getent}/bin/getent ahosts api.hetzner.cloud";
    };
    environment = {
      HCLOUD_TOKEN_FILE = config.age.secrets.hetzner-api-token.path;
    };
    path = [ builderStatusScript ];
    script = "builder-status";
  };

  systemd.timers.builder-status = {
    description = "Poll Hetzner Cloud builder status every 30s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
    };
  };

  # SSH configuration for builders (user) — Match exec provisions on-demand
  home-manager.users.${config.username}.programs.ssh.matchBlocks = {
    "builder" = {
      match = ''host ${allBuilderHostPattern} exec "${ensureBuilderScript}/bin/ensure-builder %h 3098"'';
      user = "remotebuild";
      port = 3098;
      identityFile = "/root/.ssh/builder-key";
      compression = true;
      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "${builderKnownHosts}";
        LogLevel = "ERROR";
        ConnectTimeout = "960";
        IPQoS = "cs1";
      };
    };
  };

  # SSH configuration for builders (system-wide for Nix daemon)
  programs.ssh.extraConfig = mkSshMatchBlock allBuilderHostPattern;
}
