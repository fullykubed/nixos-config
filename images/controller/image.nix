{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./headscale.nix
    ./caddy.nix
    ./niks3.nix
    ./volume.nix
    ./ssh.nix
  ];

  # System identification
  networking.hostName = "nix-controller";
  system.stateVersion = "24.05";

  users = {
    mutableUsers = false;
    allowNoPasswordLogin = true;

    # Admin user for SSH access
    users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      shell = pkgs.bash;
      home = "/home/admin";
      createHome = true;
      openssh.authorizedKeys.keys = [
        # Injected via cloud-init user-data
      ];
    };
  };

  # Allow passwordless sudo for admin user
  security.sudo.wheelNeedsPassword = false;

  # Nix daemon configuration
  nix = {
    settings = {
      trusted-users = [
        "root"
        "admin"
      ];
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = false;
    };
  };

  # Essential packages for management
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    hcloud
    jq
    cloud-init
    postgresql # For manual DB queries
    headscale # CLI for managing the headscale control plane
  ];

  # Firewall — SSH, HTTPS for headscale/Caddy, and STUN for embedded DERP
  # niks3 (port 5751) is NOT in allowedTCPPorts — it is accessible only via the
  # tailscale0 interface, which is listed in trustedInterfaces below.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80 # ACME (Let's Encrypt HTTP challenge)
      443 # HTTPS (Caddy TLS termination)
      3099 # SSH
    ];
    allowedUDPPorts = [
      3478 # STUN (embedded DERP server)
    ];
    # Trust the Tailscale interface — allows niks3 (5751) and other mesh traffic
    trustedInterfaces = [ "tailscale0" ];
  };

  # Cache doesn't need user namespaces (builder does for nix sandboxing)
  boot.kernel.sysctl."user.max_user_namespaces" = 0;

  # Disable unnecessary services to reduce attack surface
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
