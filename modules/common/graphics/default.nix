{ lib, config, ... }:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    # Enable open gl
    hardware.graphics = {
      enable = true;
      enable32Bit = false;
    };
  };
}
