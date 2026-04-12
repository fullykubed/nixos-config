{ lib, config, ... }:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    services.printing.enable = true;
  };
}
