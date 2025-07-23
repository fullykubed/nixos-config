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
  ##  Config Files
  ################################
  xdg.configFile = {
    "nvim" = {
      source = ./nvim;
      recursive = true;
    };
  };

  ################################
  ##  Sway
  ################################

  home.packages =
    with pkgs;
    [
      # Need to sort
      unstable.lazygit
      tree-sitter
      stylua

      ################################
      ##  Scanners and Printers
      ################################
      gscan2pdf # Scanning GUI

    ]
    ++ (builtins.attrValues scripts);
}
