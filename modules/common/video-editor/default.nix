{ pkgs, ... }:
let
  shotcut = pkgs.symlinkJoin {
    name = "shotcut";
    paths = [ pkgs.shotcut ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/shotcut \
        --set "QT_QPA_PLATFORM xcb"
    '';
  };
in
{
  environment.systemPackages = [
    shotcut
  ];

}
