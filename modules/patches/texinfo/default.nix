# Texinfo: Disable tests - 78/125 fail in sandbox due to locale/encoding issues
# Tests require specific locale configurations not available in Nix sandbox
# texinfoInteractive provides standalone texinfo tools (info, install-info, etc.)
_:
let
  overlay = _final: prev: {
    texinfoInteractive = prev.texinfoInteractive.overrideAttrs (_old: {
      doCheck = false;
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
