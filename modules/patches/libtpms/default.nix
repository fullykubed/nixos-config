{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (_final: _prev: {
      # libtpms 0.10.2 from unstable - fixes CVE-2026-21444
      # CVE-2026-21444 (5.5 Medium): Wrong IV returned with OpenSSL 3.x symmetric ciphers,
      # weakening subsequent encryption/decryption. Affects 0.10.0 and 0.10.1.
      # See: https://github.com/stefanberger/libtpms/security/advisories/GHSA-7jxr-4j3g-p34f
      libtpms = nixpkgs-unstable.libtpms.overrideAttrs (old: {
        # NixOSBuild AUTOFIX
        # Package name: libtpms 0.10.2
        # Error details: -Werror=stringop-overflow= fires in tpm2/AlgorithmTests.c where GCC's
        #   static analysis over-estimates the IV buffer write size. The -Wno-self-assign flag
        #   (Clang-only) also triggers an unrecognized-option note under -Werror.
        # Fix explanation: Suppress both false-positive warnings for this package only.
        env = (old.env or { }) // {
          NIX_CFLAGS_COMPILE = toString (old.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=stringop-overflow";
        };
      });
    })
  ];
}
