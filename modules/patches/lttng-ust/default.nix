# lttng-ust: Disable trivialautovarinit due to VLA incompatibility
# GCC's -ftrivial-auto-var-init=pattern uses __builtin_clear_padding which
# doesn't support variable-length aggregates used in lttng-ust's tracepoint macros
_:
let
  overlay = _final: prev: {
    lttng-ust = prev.lttng-ust.overrideAttrs (old: {
      hardeningDisable = (old.hardeningDisable or [ ]) ++ [ "trivialautovarinit" ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
