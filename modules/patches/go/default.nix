{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # Go 1.25.7 from unstable - fixes 2 CVEs not yet in NixOS 25.11 stable
      # CVE-2025-68121 (10.0 Critical): TLS session resumption bypasses changed ClientCAs/RootCAs
      # CVE-2025-61732 (8.6 High): cgo comment parsing allows code smuggling into binary
      # Fixed in Go 1.25.7 and 1.24.13 (released 2026-02-04)
      inherit (nixpkgs-unstable) go;
    })
  ];
}
