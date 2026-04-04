# Use release tarball instead of fetchgit from git.sesse.net (unreliable)
_:
let
  overlay = _final: prev: {
    plocate = prev.plocate.overrideAttrs (_old: {
      src = prev.fetchurl {
        url = "https://plocate.sesse.net/download/plocate-${prev.plocate.version}.tar.gz";
        hash = "sha256-Br07KE1dB3tEG+907bDMb44/Cm9YtMFe+GXTxGBzN4M=";
      };
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
