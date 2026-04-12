# ###############################
## Bluetooth
## See https://nixos.wiki/wiki/Bluetooth
################################

{
  pkgs,
  lib,
  config,
  ...
}:
{
  config = lib.mkIf (config.deviceType != "remote-builder") {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };
    services.blueman.enable = true;

    environment.systemPackages = with pkgs; [
      blueman # GUI for bluetooth
      bluetui # TUI for bluetooth
    ];
  };
}
