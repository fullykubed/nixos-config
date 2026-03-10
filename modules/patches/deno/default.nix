# Deno: Skip os.cpus() test that fails in sandbox due to CPU count mismatch
# The test compares two methods of getting CPU count which can differ in sandboxed builds
# Test expects 15 CPUs but sandbox reports 16
_:
let
  overlay = _final: prev: {
    deno = prev.deno.overrideAttrs (old: {
      checkFlags = (old.checkFlags or [ ]) ++ [
        "--skip=node_unit_tests::os_test"
      ];
    });
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
