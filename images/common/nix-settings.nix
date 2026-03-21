# Cloud image nix overrides (on top of modules/utility/nix-settings.nix).
# Images are ephemeral — disable GC and let each image module set trusted-users.
_: {
  nix.gc.automatic = false;
}
