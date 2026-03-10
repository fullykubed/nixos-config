_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # TagLib 1.13.1 security patch (used by VLC 3.0.x which can't use taglib 2.0+)
      # CVE-2023-47466 (CVSS 2.9-7.1 Low-High): NULL pointer dereference in updateGlobalSize()
      # Segfault via crafted WAV file where id3 chunk is the only valid chunk
      # Upstream fix: https://github.com/taglib/taglib/commit/dfa33bec0806cbb45785accb8cc6c2048a7d40cf
      # See: https://nvd.nist.gov/vuln/detail/CVE-2023-47466
      taglib_1 = prev.taglib_1.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2023-47466.patch
        ];
      });
    })
  ];
}
