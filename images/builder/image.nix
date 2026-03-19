{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./ssh.nix
    ./ccache.nix
    ./nix-daemon.nix
    ./cache-pipeline.nix
    ./inactivity-monitor.nix
  ];

  # System identity
  networking.hostName = "nix-builder";
  system.stateVersion = "24.05";

  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true;

    # Remote build user
    users.remotebuild = {
      isSystemUser = true;
      group = "remotebuild";
      shell = pkgs.bash;
      home = "/var/lib/remotebuild";
      createHome = true;
      openssh.authorizedKeys.keys = [
        # Injected via cloud-init user-data
      ];
    };
    groups.remotebuild = { };
  };

  # Essential packages
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    hcloud # For self-deletion
    jaq # For parsing Hetzner metadata
    iperf3 # For bandwidth testing via builders check
    fio # For disk performance testing via builders check
    niks3-cli # For pushing build results to cache
    ccache # Compiler cache (client-side, no daemon)
    s3fs # FUSE mount for R2-backed ccache directory
    bfs # find replacement used by builders check
  ];

  # Disable unnecessary services
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
