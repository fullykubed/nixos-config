# See https://nixos.wiki/wiki/OBS_Studio

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{

  boot.kernelModules = [

    # Virtual Camera
    "v4l2loopback"

    # Virtual Microphone
    "snd-aloop"
  ];

  # Use this to provide a virtual video sync in OBS
  boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback.out ];

  # exclusive_caps: Skype, Zoom, Teams etc. will only show device when actually streaming
  # card_label: Name of virtual camera, how it'll show up in Skype, Zoom, Teams
  # https://github.com/umlaeute/v4l2loopback
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 exclusive_caps=1 card_label="Virtual Camera"
  '';

  security.polkit.enable = true;
}
