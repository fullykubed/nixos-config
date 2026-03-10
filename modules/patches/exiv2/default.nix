{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # Exiv2 0.28.8 from unstable - fixes 3 CVEs in 0.28.7:
      # CVE-2026-25884 (CVSS 8.1 High): Out-of-bounds read in CRW image parser
      # CVE-2026-27596 (CVSS 7.5 High): Out-of-bounds read in preview component
      # CVE-2026-27631 (CVSS 5.3 Med): Uncaught exception in PSD parser
      inherit (nixpkgs-unstable) exiv2;
    })
  ];
}
