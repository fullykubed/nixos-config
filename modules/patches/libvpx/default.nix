_:
let
  patchesLib = import ../../../lib/util/nasm.nix;
in
{
  nixpkgs.overlays = [
    (_final: prev: {
      # libvpx: VP8/VP9 codec - yasm to nasm migration
      # Eliminates 22 yasm CVEs (all CVSS 5.5 Medium - DoS via malicious assembly files)
      # Requires both nativeBuildInputs swap AND --as=nasm configure flag
      libvpx = prev.libvpx.overrideAttrs (old: {
        nativeBuildInputs = patchesLib.replaceYasmWithNasm prev old.nativeBuildInputs;
        configureFlags = map (flag: if flag == "--as=yasm" then "--as=nasm" else flag) old.configureFlags;
      });
    })
  ];
}
