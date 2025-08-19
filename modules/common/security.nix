{ config, pkgs, ... }:
{
  security.auditd.enable = true; # Enable linux auditing
  security.polkit.enable = true;

  # Configure sudo with 15 minute timeout
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=15
  '';

  services.passSecretService.enable = true;
  services.dbus.packages = [ pkgs.grc ];
}
