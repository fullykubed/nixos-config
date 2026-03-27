{ pkgs, ... }:
{
  imports = [
    ../common/croc-receive.nix
    ./hardening.nix
    ./hardware.nix
    ./ssh.nix
    ./ccache.nix
    ./nix-daemon.nix
    ./cache-pipeline.nix
    ./inactivity-monitor.nix
    ./tailscale.nix
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
        # Injected via croc-based secret transfer
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
    jaq # For parsing JSON (tailscale status, etc.)
    iperf3 # For bandwidth testing via builders check
    fio # For disk performance testing via builders check
    niks3-cli # For pushing build results to cache
    ccache # Compiler cache (client-side, no daemon)
    s3fs # FUSE mount for R2-backed ccache directory
    bfs # find replacement used by builders check
  ];

  services = {
    # SSH server configuration
    # Host key is injected via croc-based secret transfer; disable auto-generation
    # so we use a known key that the client can verify.
    # SSH listens on 0.0.0.0 but the public firewall allows no inbound ports;
    # only Tailscale peers (via the trusted tailscale0 interface) can reach it.
    openssh = {
      enable = true;
      ports = [ 3098 ];
      hostKeys = [ ]; # croc-receive writes our static host key before sshd starts
      extraConfig = "HostKey /etc/ssh/ssh_host_ed25519_key";
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        X11Forwarding = false;
        AllowAgentForwarding = false;
        AllowTcpForwarding = "local";
        MaxAuthTries = 3;
        LoginGraceTime = 30;
        MaxSessions = 10;
        LogLevel = "VERBOSE";
        Ciphers = [ "chacha20-poly1305@openssh.com" ];
        KexAlgorithms = [ "sntrup761x25519-sha512@openssh.com" ];
        Macs = [ "hmac-sha2-512-etm@openssh.com" ];
      };
    };

    # cloud-init writes the croc relay password and croc code to /run at boot;
    # croc-receive.service picks these up to retrieve the full secret bundle.
    cloud-init = {
      enable = true;
      network.enable = true;
    };

    croc-receive = {
      enable = true;
      relayAddress = "headscale.panfactumcf.com:19009";
    };
  };

  # Disable unnecessary services
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
