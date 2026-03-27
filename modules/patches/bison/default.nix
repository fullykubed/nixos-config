# Bison: Disable installcheck - test 257 (%expect-rr non GLR) fails with
# trivialautovarinit hardening flag (-ftrivial-auto-var-init=pattern)
_:
let
  overlay = _final: prev: {
    bison = prev.bison.overrideAttrs (_old: {
      doInstallCheck = false;
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
