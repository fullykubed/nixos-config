# Shared CAS configuration applied to all NixOS systems and disk images
# Enables content-addressed derivation outputs globally via nixpkgs config.
# The ca-derivations experimental feature must be enabled on the Nix daemon
# for this to work.
#
{
  nix.settings = {
    experimental-features = [
      "ca-derivations"
      "blake3-hashes"
      "git-hashing"
    ];
  };
}
