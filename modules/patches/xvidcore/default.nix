_:
let
  patchesLib = import ../../../lib/util/nasm.nix;
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      # xvidcore: MPEG-4 codec - yasm to nasm migration
      # Eliminates 22 yasm CVEs (all CVSS 5.5 Medium - DoS via malicious assembly files)
      # Simple swap - nasm is a drop-in replacement
      xvidcore = prev.xvidcore.overrideAttrs (old: {
        nativeBuildInputs = patchesLib.replaceYasmWithNasm prev old.nativeBuildInputs;
      });
    })
  ];
}
