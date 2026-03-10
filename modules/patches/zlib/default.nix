# zlib security patch
# CVE-2026-27171 (CVSS 2.9 Low / 5.5 Med): CPU exhaustion via infinite loop
# crc32_combine64/crc32_combine_gen64 enter infinite loop on negative len2
# Fix adds early return for negative lengths in both functions
# See: https://nvd.nist.gov/vuln/detail/CVE-2026-27171
_:
let
  overlay = _final: prev: {
    zlib = prev.zlib.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ./CVE-2026-27171.patch
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
