_:
let
  patchesLib = import ../../../lib/util/nasm.nix;
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      # libaom: AV1 codec - yasm to nasm migration
      # Eliminates 22 yasm CVEs (all CVSS 5.5 Medium - DoS via malicious assembly files)
      # Requires fix for cmake bug: uses -hf output to check for -Ox (which is in -hO)
      libaom = prev.libaom.overrideAttrs (old: {
        nativeBuildInputs = patchesLib.replaceYasmWithNasm prev old.nativeBuildInputs;

        postPatch = (old.postPatch or "") + ''
          # Fix libaom cmake bug: it runs 'nasm -hf' but checks for '-Ox' which
          # is only in 'nasm -hO' output. Add separate check for optimization support.
          sed -i '/^function(test_nasm)/,/^endfunction()/ {
            s|execute_process(COMMAND ''${CMAKE_ASM_NASM_COMPILER} -hf|execute_process(COMMAND ''${CMAKE_ASM_NASM_COMPILER} -hO\n                  OUTPUT_VARIABLE nasm_opt_helptext)\n  execute_process(COMMAND ''${CMAKE_ASM_NASM_COMPILER} -hf|
            s|if(NOT "''${nasm_helptext}" MATCHES "-Ox")|if(NOT "''${nasm_opt_helptext}" MATCHES "-Ox")|
          }' build/cmake/aom_optimization.cmake
        '';
      });
    })
  ];
}
