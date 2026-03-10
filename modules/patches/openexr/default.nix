_: {
  nixpkgs.overlays = [
    (final: prev: {
      # OpenJPH - JPEG2000 HTJ2K codec library (required by OpenEXR 3.4+)
      # Used for High Throughput JPEG 2000 support in OpenEXR
      openjph = prev.stdenv.mkDerivation rec {
        pname = "openjph";
        version = "0.24.5";
        src = prev.fetchFromGitHub {
          owner = "aous72";
          repo = "OpenJPH";
          rev = version;
          sha256 = "0c46fjx82ncw1hhz8k045qgz6lxpp9klx543izvn71yzbi1g2gbb";
        };
        nativeBuildInputs = [ prev.cmake ];
        cmakeFlags = [
          "-DBUILD_SHARED_LIBS=ON"
          "-DOJPH_BUILD_EXECUTABLES=OFF"
          "-DOJPH_BUILD_TESTS=OFF"
          "-DOJPH_ENABLE_TIFF_SUPPORT=OFF"
        ];
        meta = {
          description = "Open source implementation of JPEG2000 Part-15 (HTJ2K)";
          homepage = "https://github.com/aous72/OpenJPH";
          license = prev.lib.licenses.bsd2;
        };
      };

      # OpenEXR 3.4.5 - Security update from 3.3.5
      # Fixes 10 CVEs total including:
      #   CVE-2025-64181 (7.5 High): Use of uninitialized memory -> DoS
      #   CVE-2025-64182 (7.8 High): Memory safety bug in Python adapter -> RCE
      #   CVE-2025-12495 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27946)
      #   CVE-2025-12839 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27947)
      #   CVE-2025-12840 (7.8 High): Heap buffer overflow RCE via EXR parsing (ZDI-CAN-27948)
      # See: https://github.com/AcademySoftwareFoundation/openexr/releases/tag/v3.4.5
      openexr = prev.openexr.overrideAttrs (old: rec {
        version = "3.4.5";
        src = prev.fetchFromGitHub {
          owner = "AcademySoftwareFoundation";
          repo = "openexr";
          rev = "v${version}";
          sha256 = "0p0jj5xi8brjqhfmk6h7mxa0afmv94gxhypcna3zv1v4lsxkg3hq";
        };
        buildInputs = (old.buildInputs or [ ]) ++ [ final.openjph ];
      });
    })
  ];
}
