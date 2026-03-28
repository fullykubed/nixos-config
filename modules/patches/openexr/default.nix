# OpenEXR 3.4.7 - Security update from 3.3.5
# Fixes 11+ CVEs total including:
#   CVE-2026-27622 (7.8 High): CompositeDeepScanLine integer overflow -> heap OOB write (RCE)
#   CVE-2026-26981 (6.5 Med): istream_nonparallel_read signed-to-unsigned -> OOB read (DoS)
#   CVE-2025-64181 (7.5 High): Use of uninitialized memory -> DoS
#   CVE-2025-12495 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27946)
#   CVE-2025-12839 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27947)
#   CVE-2025-12840 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27948)
#   CVE-2025-48071 (7.8 High): Deep scan-line ZIPS heap overflow (RCE)
# OpenJPH is now vendored internally (v0.26.3) as of 3.4.6.
# See: https://github.com/AcademySoftwareFoundation/openexr/releases/tag/v3.4.7
_:
let
  overlay = _final: prev: {
    openexr = prev.openexr.overrideAttrs (_old: rec {
      version = "3.4.7";
      src = prev.fetchFromGitHub {
        owner = "AcademySoftwareFoundation";
        repo = "openexr";
        rev = "v${version}";
        sha256 = "18qi0xigxp5awrzbcr2ff2725dypbd92x5q658hgj3rgsaynlqbj";
      };
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
