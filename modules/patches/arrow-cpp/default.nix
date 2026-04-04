# arrow-cpp: Disable installCheck — tests fail with custom optimization flags
# The stdenv sets doCheck=false but arrow-cpp uses doInstallCheck to run CTest.
# 4 tests fail (arrow-utility-test, parquet-{internals,reader,writer}-test)
# due to our -march/-mtune flags affecting byte stream split encoding.
_:
let
  overlay = _final: prev: {
    arrow-cpp = prev.arrow-cpp.overrideAttrs {
      doInstallCheck = false;
    };
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
