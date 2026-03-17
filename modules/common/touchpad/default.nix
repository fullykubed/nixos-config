{ config, lib, ... }:
{
  config = lib.mkIf (config.deviceType == "laptop") {
    services.libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        disableWhileTyping = true;
      };
    };
  };
}
