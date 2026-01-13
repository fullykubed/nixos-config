{ pkgs, ... }:
{
  systemd.user.extraConfig = "DefaultLimitNOFILE=65536";

  environment.systemPackages = with pkgs; [
    systemd-manager-tui
  ];
}
