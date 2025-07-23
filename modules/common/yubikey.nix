{ config, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    yubikey-manager # Working with yubikey hardware tokens
    age-plugin-yubikey # age and rage integrations with yubikeys
    yubikey-personalization # Another yubikey CLI
    yubikey-personalization-gui
  ];

  services.pcscd.enable = true; # need for working with yubikey
}
