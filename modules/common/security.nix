{ config, pkgs, ... }:
let
  # Create a sudo wrapper script for backwards compatibility
  sudo-compat = pkgs.writeShellScriptBin "sudo" ''
    exec doas "''${@/--preserve-env*/}"
  '';
in
{
  security.auditd.enable = true; # Enable linux auditing
  security.polkit.enable = true;

  # Disable sudo and use doas instead
  security.sudo.enable = false;

  # Configure doas
  security.doas = {
    enable = true;
    extraRules = [
      {
        users = [ config.username ];
        persist = true; # Keep authentication for 5 minutes by default
        keepEnv = true; # Preserve environment variables
      }
    ];
  };

  # Add sudo compatibility wrapper
  environment.systemPackages = [ sudo-compat ];

  services.passSecretService.enable = true;
  services.dbus.packages = [ pkgs.grc ];
}
