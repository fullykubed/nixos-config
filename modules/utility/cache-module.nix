# Shared binary cache configuration applied to all NixOS systems and disk images
{
  nix.settings = {
    extra-substituters = [
      "https://install.determinate.systems"
      "https://nix-community.cachix.org"
      "https://nixos-cache.panfactumcf.com?priority=42" # niks3 binary cache
    ];
    extra-trusted-public-keys = [
      "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache-1:L8UZuJh5BeVhxU06bO4iT0OkWSvKO7/nFV1XuOwt9ak=" # niks3 signing key
    ];
  };
}
