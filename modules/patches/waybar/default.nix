# waybar: Disable tests - catch2 not found via pkg-config with custom stdenv
# Tests are skipped anyway (doCheck = false)
_:
let
  overlay = _final: prev: {
    waybar = prev.waybar.overrideAttrs (old: {
      mesonFlags = (old.mesonFlags or [ ]) ++ [
        "-Dtests=disabled"
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
