{ lib, config, ... }:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    hardware.keyboard.zsa.enable = true;
  };
}
