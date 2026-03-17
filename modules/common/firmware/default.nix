{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.firmwareType == "coreboot") {
    # Firmware updates via LVFS (e.g. Star Labs publishes firmware via LVFS)
    services.fwupd.enable = true;

    # flashrom required for coreboot firmware updates
    environment.systemPackages = [ pkgs.flashrom ];
  };
}
