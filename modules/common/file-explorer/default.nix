# Thunar is a GUI file manager that is Wayland compatible

{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    ./thunar.nix
    ./ranger
  ];
}
