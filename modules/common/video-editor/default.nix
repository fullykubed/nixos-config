{
  pkgs,
  lib,
  config,
  ...
}:
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
  config = lib.mkIf (config.deviceType != "remote-builder") {
    environment.systemPackages = [
      shotcut
    ];
  };
}
