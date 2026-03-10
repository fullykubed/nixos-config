# onnxruntime: Disable unit tests to avoid CMake 4 GTest detection regression
# CMake 4 changed find_package behavior, breaking GTest::gtest target detection
# Tests are skipped anyway (doCheck = false), so just disable at CMake level
# See: https://github.com/NixOS/nixpkgs/issues/445447
# Alt fix (may not work): "-DCMAKE_POLICY_VERSION_MINIMUM=3.10"
_:
let
  overlay = _final: prev: {
    onnxruntime = prev.onnxruntime.overrideAttrs (old: {
      cmakeFlags = (old.cmakeFlags or [ ]) ++ [
        "-Donnxruntime_BUILD_UNIT_TESTS=OFF"
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
