{ pkgs, ... }:
{
  imports = [
    ../common/croc-receive.nix
    ./hardening.nix
    ./hardware.nix
    ./headscale.nix
    ./caddy.nix
    ./croc.nix
    ./niks3.nix
    ./volume.nix
    ./ssh.nix
  ];

  services.croc-receive = {
    enable = true;
    relayAddress = "localhost:19009";
    localRelay = true;
  };

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

  # Controller-specific nix overrides (base settings from modules/utility/nix-settings.nix)
  nix.settings.trusted-users = [
    "root"
    "admin"
  ];

  # Essential packages for management
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    htop
    hcloud
    jaq
    cloud-init
    cryptsetup
    postgresql # For manual DB queries
    headscale # CLI for managing the headscale control plane
  ];

  # Firewall — SSH, HTTPS for headscale/Caddy, and STUN for embedded DERP
  # SSH stays publicly accessible for emergency recovery if Tailscale is down.
  # niks3 (port 5751) is NOT in allowedTCPPorts — it is accessible only via the
  # tailscale0 interface (trustedInterfaces, set in the tailscale module).
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80 # ACME (Let's Encrypt HTTP challenge)
      443 # HTTPS (Caddy TLS termination)
    ];
    allowedUDPPorts = [
      3478 # STUN (embedded DERP server)
    ];
  };

  # Cache doesn't need user namespaces (builder does for nix sandboxing)
  boot.kernel.sysctl."user.max_user_namespaces" = 0;

  # Disable unnecessary services to reduce attack surface
  documentation.enable = false;
  programs.command-not-found.enable = false;
}
