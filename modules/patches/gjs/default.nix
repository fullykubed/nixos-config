# gjs: Skip GTK tests - GTK not found in sandbox with custom stdenv
# Tests are skipped anyway (doCheck = false)
_:
let
  overlay = _final: prev: {
    gjs = prev.gjs.overrideAttrs (old: {
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Dskip_gtk_tests=true"
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
