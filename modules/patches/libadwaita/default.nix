# libadwaita: Skip test-dialog which fails in sandbox with custom stdenv
# Error: "XDG_RUNTIME_DIR is invalid" + "Failed to open display" → SIGTRAP
# 65/66 tests pass; test-dialog has display requirements xvfb-run doesn't fully satisfy
# when combined with our hardening flags and sanitizer options
_:
let
  overlay = _final: prev: {
    libadwaita = prev.libadwaita.overrideAttrs (old: {
      mesonCheckFlags = (old.mesonCheckFlags or [ ]) ++ [
        "--exclude"
        "test-dialog"
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
