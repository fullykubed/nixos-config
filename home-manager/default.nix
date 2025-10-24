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

    ]
    ++ (builtins.attrValues scripts);
}
