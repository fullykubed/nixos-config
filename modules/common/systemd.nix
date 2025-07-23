{ config, ... }:
{
  systemd.user.extraConfig = "DefaultLimitNOFILE=65536";
}
