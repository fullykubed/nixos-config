# Sway: Fix maybe-uninitialized warning in view_populate_pid
# GCC inlining + trivialautovarinit + -Werror triggers false positive for pid variable
_:
let
  overlay = _final: prev: {
    sway-unwrapped = prev.sway-unwrapped.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        sed -i 's/pid_t pid;/pid_t pid = 0;/' sway/tree/view.c
      '';
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
