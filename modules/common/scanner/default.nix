{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    naps2
  ];
}
