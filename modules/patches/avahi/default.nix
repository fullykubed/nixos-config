_:
let
  overlay = _final: prev: {
    avahi = prev.avahi.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./CVE-2025-68468.patch
        ./CVE-2025-68471.patch
        ./CVE-2025-68276.patch
        ./CVE-2026-24401.patch
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
