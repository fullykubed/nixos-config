{ config, pkgs, ... }:
{
  security.auditd.enable = true; # Enable linux auditing
  security.polkit.enable = true;
  services.passSecretService.enable = true;
  services.dbus.packages = [ pkgs.grc ];
}
