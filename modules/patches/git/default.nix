# Git: Disable tests - multiple tests fail in Nix sandbox due to:
# - file:// protocol restrictions (CVE-2022-39253 mitigation)
# - sandbox environment isolation issues
# The installed git binary is unaffected.
_:
let
  overlay = _final: prev: {
    gitMinimal = prev.gitMinimal.overrideAttrs { doInstallCheck = false; };
    git = prev.git.overrideAttrs { doInstallCheck = false; };
    gitFull = prev.gitFull.overrideAttrs { doInstallCheck = false; };
  };
in
{
  nixpkgs.overlays = [ overlay ];
  nixpkgs-unstable.overlays = [ overlay ];
}
