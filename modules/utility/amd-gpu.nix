{ pkgs, ... }:
{
  services.xserver.videoDrivers = [ "amdgpu" ];
  programs.corectrl.enable = true;
  environment.systemPackages = with pkgs; [
    radeontop # GPU monitoring
  ];
}
