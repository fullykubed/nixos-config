{ nixpkgs-unstable, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      # GIMP 3.0.8 - fixes 9 additional CVEs over 3.0.6 (all 7.8 High severity):
      # - CVE-2025-14422: PNM integer overflow -> RCE (ZDI-CAN-28273)
      # - CVE-2025-14423: LBM stack buffer overflow -> RCE (ZDI-CAN-28311)
      # - CVE-2025-14424: XCF use-after-free -> RCE (ZDI-CAN-28376)
      # - CVE-2025-14425: JP2 heap buffer overflow -> RCE (ZDI-CAN-28248)
      # - CVE-2025-15059: PSP heap buffer overflow -> RCE (ZDI-CAN-28232)
      # - CVE-2026-2044: PGM uninitialized memory -> RCE (ZDI-CAN-28158)
      # - CVE-2026-2045: XWD out-of-bounds write -> RCE (ZDI-CAN-28265)
      # - CVE-2026-2047: ICNS heap buffer overflow -> RCE (ZDI-CAN-28530)
      # NOTE: Override openexr to use our patched version (eliminates openexr-3.3.5 CVEs)
      # NOTE: Override gegl to use our patched openexr (eliminates openexr_2 CVEs)
      # NOTE: Override ghostscript to use our patched jbig2dec (CVE-2023-46361)
      # NOTE: Override libjxl to use our patched openexr (eliminates openexr-3.3.5 CVEs)
      gimp =
        (nixpkgs-unstable.gimp.override {
          inherit (final) openexr;
          gegl = nixpkgs-unstable.gegl.override {
            openexr_2 = final.openexr;
          };
          ghostscript = nixpkgs-unstable.ghostscript.override {
            inherit (final) jbig2dec;
          };
          libjxl = nixpkgs-unstable.libjxl.override { inherit (final) openexr; };
        }).overrideAttrs
          (old: {
            version = "3.0.8";
            src = prev.fetchurl {
              url = "https://download.gimp.org/gimp/v3.0/gimp-3.0.8.tar.xz";
              hash = "sha256-/rSYrMAbJoJ8/x/5Wqj7gs3Wpg16v3c8/NGavq/KM4Y=";
            };
            # Drop fix-gegl-bevel-test.patch - already applied upstream in 3.0.8
            patches = builtins.filter (p: !(prev.lib.hasSuffix "fix-gegl-bevel-test.patch" (toString p))) (
              old.patches or [ ]
            );
            # 3.0.8 changed find_installation() (no args = meson's own python) from
            # find_installation('python3') (searches PATH, finds wrapped python w/ pygobject).
            # Restore the PATH-based lookup so the nixpkgs python3.withPackages wrapper is found.
            # 3.0.8 added bash-completion and glibcLocales as new dependencies
            buildInputs = (old.buildInputs or [ ]) ++ [ prev.bash-completion ];
            nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.glibcLocales ];
            # gen-languages needs a locale for setlocale()
            LOCALE_ARCHIVE = "${prev.glibcLocales}/lib/locale/locale-archive";
            postPatch = (old.postPatch or "") + ''
              substituteInPlace meson.build \
                --replace-fail "import('python').find_installation()" \
                               "import('python').find_installation('python3')"
              # Disable 2 UI tests that SIGTRAP in sandbox (upstream GIMP #15763)
              substituteInPlace app/tests/meson.build \
                --replace-fail "'single-window-mode'," "#'single-window-mode'," \
                --replace-fail "'ui'," "#'ui',"
            '';
          });
    })
  ];
}
