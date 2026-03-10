_:
let
  # libsndfile security patches (3 CVEs patched, 1 has no upstream fix)
  # CVE-2025-52194 (CVSS 7.5 High): Buffer overflow in IRCAM header parsing
  # CVE-2024-50612 (CVSS 5.5 Medium): Out-of-bounds read in OGG Vorbis
  # CVE-2025-56226 (CVSS 5.3 Medium): Memory leak in MP3 encoder init
  # NOTE: CVE-2024-50613 (6.5 Med) has no upstream fix - whitelisted separately
  overlay = _final: prev: {
    libsndfile = prev.libsndfile.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./CVE-2025-52194.patch
        ./CVE-2024-50612.patch
        ./CVE-2025-56226.patch
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
