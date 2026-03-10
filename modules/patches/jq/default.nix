{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # jq 1.8.1 - force all packages to use non-vulnerable version
      # CVE-2024-23337 (4.3 Med): Integer overflow at index 2147483647 -> DoS
      # CVE-2024-53427 (8.1 High): Stack buffer overflow in decNumberCopy -> RCE
      # CVE-2025-48060 (7.5 High): Heap buffer overflow in jv_string_vfmt
      # All fixed in jq 1.8+
      inherit (nixpkgs-unstable) jq;
    })
  ];
}
