{ config, lib, ... }:
{
  config = lib.mkIf (config.deviceType == "laptop") {
    programs.light = {
      enable = true;
      brightnessKeys.enable = true;
    };
  };
}
