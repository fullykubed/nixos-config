# libssh: CVE-2026-3731 (CVSS 5.3 Medium): OOB read in SFTP extension name handler
# See: https://nvd.nist.gov/vuln/detail/CVE-2026-3731
_: {
  nixpkgs-unstable.overlays = [
    (_final: prev: {
      libssh = prev.libssh.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2026-3731.patch
        ];
      });
    })
  ];
}
