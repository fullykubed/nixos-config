{
  config,
  pkgs,
  lib,
  ...
}:
let
  scripts = with pkgs; { };
in
{
  home.stateVersion = "22.11";

  ################################
  ##  Sway
  ################################

  home.packages =
    with pkgs;
    [
      # Need to sort

      ################################
      ##  Scanners and Printers
      ################################
      gscan2pdf # Scanning GUI

    ]
    ++ (builtins.attrValues scripts);
}
