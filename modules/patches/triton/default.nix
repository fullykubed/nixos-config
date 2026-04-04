# triton: Two fixes for building with our custom stdenv
#
# 1. ccache hook clears cmakeFlags — The custom stdenv ccache hook
#    (preConfigure) absorbs cmakeFlags into cmakeFlagsArray then sets
#    cmakeFlags="". Triton's setup.py reads cmake args from
#    os.environ['cmakeFlags'], so LLD_DIR and LLVM_SYSPATH are lost —
#    causing find_package(LLD) to fail for the AMD backend.
#    Fix: save cmakeFlags before ccache clears it, redirect setup.py to
#    read from the saved copy.
#
# 2. GCC 14 -Werror false positive — triton hardcodes -Werror in
#    CMakeLists.txt:149. GCC 14 emits a spurious -Wstringop-overflow
#    warning in Ops.cpp (memmove into a just-allocated vector), which
#    becomes a fatal error.
#    Fix: strip -Werror from CMAKE_CXX_FLAGS in CMakeLists.txt.
{ lib, ... }:
let
  overlay = _final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (
        _pyfinal: pyprev:
        lib.optionalAttrs (pyprev ? triton) {
          triton = pyprev.triton.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace setup.py \
                --replace-fail "get('cmakeFlags'" "get('_TRITON_CMAKE_FLAGS'"
              substituteInPlace CMakeLists.txt \
                --replace-fail "-Werror " ""
            '';
            preConfigure = ''
              export _TRITON_CMAKE_FLAGS="$cmakeFlags"
            ''
            + (old.preConfigure or "");
          });
        }
      )
    ];
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
