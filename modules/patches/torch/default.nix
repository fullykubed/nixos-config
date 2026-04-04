# torch: Fix SLEEF SVE cross-arch cache pollution from fbgemm
#
# fbgemm/CMakeLists.txt unconditionally runs
#   check_cxx_compiler_flag(-march=armv8-a+sve COMPILER_SUPPORTS_SVE)
# on all non-MSVC platforms. The result is cached and leaks to sleef,
# which iterates SLEEF_SUPPORTED_LIBM_EXTENSIONS (includes SVE for all
# architectures) and builds ARM SVE targets on x86_64 — failing with
# "Please specify SVE flags" / missing arm_sve.h.
#
# Fix: guard fbgemm's ARM flag checks behind a CMAKE_SYSTEM_PROCESSOR
# aarch64 check, matching how sleef itself gates SVE detection.
{ lib, ... }:
let
  overlay = _final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (
        _pyfinal: pyprev:
        lib.optionalAttrs (pyprev ? torch) {
          torch = pyprev.torch.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace third_party/fbgemm/CMakeLists.txt \
                --replace-fail \
                  "check_cxx_compiler_flag(-march=armv8-a+sve COMPILER_SUPPORTS_SVE)" \
                  "if(CMAKE_SYSTEM_PROCESSOR MATCHES \"aarch64|arm64\")
              check_cxx_compiler_flag(-march=armv8-a+sve COMPILER_SUPPORTS_SVE)" \
                --replace-fail \
                  "check_cxx_compiler_flag(-march=armv8-a+fp16fml COMPILER_SUPPORTS_FP16FML)" \
                  "check_cxx_compiler_flag(-march=armv8-a+fp16fml COMPILER_SUPPORTS_FP16FML)
              endif()"
            '';
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
