# Coreutils: Skip tests that fail with hardening flags or in sandbox
# - du/deref: tmpfs block counting differs with -L flag
# - du/inacc-dir: output differs with hardening flags
# - split/line-bytes: binary comparison fails with trivialautovarinit
_:
let
  overlay = _final: prev: {
    coreutils = prev.coreutils.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        echo 'exit 77' > tests/du/deref.sh
        echo 'exit 77' > tests/du/inacc-dir.sh
        echo 'exit 77' > tests/split/line-bytes.sh
      '';
    });

    coreutils-full = prev.coreutils-full.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        echo 'exit 77' > tests/du/deref.sh
        echo 'exit 77' > tests/du/inacc-dir.sh
        echo 'exit 77' > tests/split/line-bytes.sh
      '';
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
