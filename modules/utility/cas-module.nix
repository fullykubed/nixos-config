# Shared CAS configuration applied to all NixOS systems and disk images
# Enables content-addressed experimental features on the Nix daemon:
#   ca-derivations  — allow content-addressed derivation outputs
#   blake3-hashes   — faster multi-threaded content hashing
#   git-hashing     — Git-native store object hashing
#
# contentAddressedByDefault is NOT enabled yet — these features are available
# for per-package opt-in via __contentAddressed = true.
{
  nix.settings = {
    extra-experimental-features = [
      "ca-derivations"
      "blake3-hashes"
      "git-hashing"
    ];
  };
}
