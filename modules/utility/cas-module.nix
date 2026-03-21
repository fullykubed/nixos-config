# Shared CAS configuration applied to all NixOS systems and disk images
# Enables content-addressed derivation outputs globally via nixpkgs config.
# The ca-derivations experimental feature must be enabled on the Nix daemon
# for this to work.
{
  nix.settings = {
    experimental-features = [
      "ca-derivations"
      "blake3-hashes"
      "git-hashing"
    ];
  };

  # Disabled until https://github.com/NixOS/nix/issues/15003 is resolved —
  # closure-info cannot parse CA placeholder paths on Nix 2.33.x, crashing
  # the daemon during full NixOS system builds.
  nixpkgs.config.contentAddressedByDefault = false;
}
