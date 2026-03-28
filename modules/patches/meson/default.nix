# Meson: disable installCheck to prevent timeout on remote builders
#
# Meson runs its full project test suite (run_project_tests.py) during
# installCheckPhase. Test case "common/227 very long command line" compiles
# hundreds of files with extremely long names through the ccache wrapper,
# producing no output for 30+ minutes and triggering the builder's 1800s
# silence timeout.
_:
let
  overlay = _final: prev: {
    meson = prev.meson.overrideAttrs { doInstallCheck = false; };
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
