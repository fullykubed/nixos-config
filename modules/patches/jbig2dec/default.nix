_: {
  nixpkgs.overlays = [
    (_final: prev: {
      # jbig2dec security patch
      # CVE-2023-46361 (CVSS 6.5 Medium): SEGV via uninitialized allocator in CLI tool
      # Uninitialized jbig2dec_allocator_t in main() causes crash on malformed JBIG2 files
      # Affects CLI tool only (libjbig2dec library is not affected)
      # Fixed upstream: https://github.com/ArtifexSoftware/jbig2dec/commit/ee53a7e4bc7819d32e8c0b2057885bcc97586bf3
      # See: https://nvd.nist.gov/vuln/detail/CVE-2023-46361
      jbig2dec = prev.jbig2dec.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./CVE-2023-46361.patch
        ];
      });
    })
  ];
}
