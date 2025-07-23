# See https://nixos.wiki/wiki/PipeWire

{ config, pkgs, ... }:
{
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  environment.systemPackages = with pkgs; [
    pavucontrol # For controlling audio sinks
    helvum # Controlling pipewire
  ];
}
