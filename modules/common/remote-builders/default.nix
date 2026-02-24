{
  config,
  lib,
  pkgs,
  ...
}:
let
  maxRegularBuilders = 3;
  maxBigBuilders = 1;

  # Base64-encoded builder host public key for nix buildMachines publicHostKey.
  # This is: base64 -w0 secrets/builder-host-key.pub
  builderHostPublicKey = builtins.readFile ../../../secrets/builder-host-key.pub;
  builderHostPublicKeyBase64 = builtins.replaceStrings [ "\n" ] [ "" ] (
    builtins.readFile (
      pkgs.runCommand "builder-host-key-base64" { } ''
        ${pkgs.coreutils}/bin/base64 -w0 ${../../../secrets/builder-host-key.pub} > $out
      ''
    )
  );

  # Known hosts file for SSH host key verification
  builderKnownHosts = pkgs.writeText "builder-known-hosts" (
    let
      hostKey = lib.removeSuffix "\n" builderHostPublicKey;
      regularEntries = lib.genList (n: "builder-${toString (n + 1)} ${hostKey}") maxRegularBuilders;
      bigEntries = lib.genList (n: "big-builder-${toString (n + 1)} ${hostKey}") maxBigBuilders;
    in
    lib.concatStringsSep "\n" (regularEntries ++ bigEntries) + "\n"
  );

  # CLI tool for managing builders (defined first so proxy can use it)
  buildersCli = pkgs.writeShellApplication {
    name = "builders";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jq
      pkgs.bc
      pkgs.iperf3
      pkgs.ncurses
    ];
    text = builtins.readFile ./builders-cli.sh;
  };

  # Proxy command for SSH that provisions builders on-demand
  builderProxyScript = pkgs.writeShellApplication {
    name = "hetzner-builder-proxy";
    runtimeInputs = [
      pkgs.hcloud
      pkgs.jq
      pkgs.netcat-gnu
      pkgs.socat
      pkgs.openssh
      buildersCli
    ];
    text = builtins.readFile ./proxy-command.sh;
  };

  # Regular builders: 4 cores per job, max jobs = cores / 2
  mkRegularBuilder = n: {
    hostName = "builder-${toString n}";
    sshUser = "remotebuild";
    sshKey = "/root/.ssh/builder-key";
    system = "x86_64-linux";
    maxJobs = 4;
    speedFactor = 1;
    supportedFeatures = [
      "nixos-test"
      "kvm"
      "benchmark"
    ];
    mandatoryFeatures = [ ];
    publicHostKey = builderHostPublicKeyBase64;
  };

  # Big-parallel builders: 1 job using all cores
  mkBigBuilder = n: {
    hostName = "big-builder-${toString n}";
    sshUser = "remotebuild";
    sshKey = "/root/.ssh/builder-key";
    system = "x86_64-linux";
    maxJobs = 1;
    speedFactor = 1;
    supportedFeatures = [
      "nixos-test"
      "big-parallel"
      "kvm"
      "benchmark"
    ];
    mandatoryFeatures = [ "big-parallel" ];
    publicHostKey = builderHostPublicKeyBase64;
  };

  regularBuilders = lib.genList (n: mkRegularBuilder (n + 1)) maxRegularBuilders;
  bigBuilders = lib.genList (n: mkBigBuilder (n + 1)) maxBigBuilders;
  builders = regularBuilders ++ bigBuilders;

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
in
{
  nix = {
    distributedBuilds = true;
    buildMachines = builders;
    settings.builders-use-substitutes = true;
  };

  environment = {
    systemPackages = [
      buildersCli
      pkgs.hcloud # Hetzner Cloud CLI
      pkgs.bc # Calculator for cost estimation
      pkgs.socat # For SSH proxy command
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

  # Systemd service that polls hcloud for builder status and writes to a
  # world-readable file so unprivileged processes (waybar) can read it.
  systemd.services.builder-status = {
    description = "Poll Hetzner Cloud for builder server status";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "builder-status";
      RuntimeDirectoryPreserve = "yes";
      EnvironmentFile = ""; # clear any inherited env
    };
    path = [
      pkgs.hcloud
      pkgs.jq
    ];
    script = ''
      export HCLOUD_TOKEN
      HCLOUD_TOKEN=$(cat ${config.age.secrets.hetzner-api-token.path})
      hcloud server list -o json -l builder=true > /run/builder-status/status.json
      chmod 0644 /run/builder-status/status.json
    '';
  };

  systemd.timers.builder-status = {
    description = "Poll Hetzner Cloud builder status every 30s";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10s";
      OnUnitActiveSec = "30s";
    };
  };

  # SSH configuration for builders (user)
  home-manager.users.${config.username}.programs.ssh.matchBlocks = {
    "builder-*" = {
      user = "remotebuild";
      port = 3098;
      identityFile = "/root/.ssh/builder-key";
      compression = true;
      proxyCommand = "${builderProxyScript}/bin/hetzner-builder-proxy %h %p";
      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "${builderKnownHosts}";
        LogLevel = "ERROR";
        ConnectTimeout = "180";
        IPQoS = "cs1";
      };
    };
    "big-builder-*" = {
      user = "remotebuild";
      port = 3098;
      identityFile = "/root/.ssh/builder-key";
      compression = true;
      proxyCommand = "${builderProxyScript}/bin/hetzner-builder-proxy %h %p";
      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "${builderKnownHosts}";
        LogLevel = "ERROR";
        ConnectTimeout = "180";
        IPQoS = "cs1";
      };
    };
  };

  # SSH configuration for builders (system-wide for Nix daemon)
  programs.ssh.extraConfig = ''
    Host builder-* big-builder-*
      User remotebuild
      Port 3098
      IdentityFile /root/.ssh/builder-key
      ProxyCommand ${builderProxyScript}/bin/hetzner-builder-proxy %h %p
      StrictHostKeyChecking yes
      UserKnownHostsFile ${builderKnownHosts}
      LogLevel ERROR
      ConnectTimeout 180
      Compression yes
      IPQoS cs1
  '';
}
