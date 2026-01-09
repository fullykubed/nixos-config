{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    yubikey-manager # Working with yubikey hardware tokens
    age-plugin-yubikey # age and rage integrations with yubikeys
    yubikey-personalization # Another yubikey CLI
    yubioath-flutter # GUI for yubikey
  ];

  services.pcscd.enable = true; # need for working with yubikey
}
