_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # BusyBox security patches
      # stdenv reference checks disabled in flake.nix to allow bootstrap patching
      # CVE-2025-60876 (CVSS 6.5 Medium): HTTP header injection via CRLF in wget URLs
      # CVE-2025-46394 (CVSS 3.2 Low): Filename hiding via terminal escape sequences in tar
      busybox = prev.busybox.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2025-60876.patch
          ./CVE-2025-46394.patch
          ./CVE-2025-46394-2.patch
        ];
      });
    })
  ];
}
