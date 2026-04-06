{ pkgs, ... }:

let
  sysz = pkgs.writeShellApplication {
    name = "sysz";
    runtimeInputs = [
      pkgs.systemd
      pkgs.fzf
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
    ];
    excludeShellChecks = [
      "SC2086" # word splitting (intentional in some places)
      "SC2016" # single-quoted variables (intentional inside fzf preview commands)
    ];
    text = builtins.readFile ./sysz.sh;
  };
in
{
  environment.systemPackages = [ sysz ];
}
