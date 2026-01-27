# Adding a New Machine

1. Create device configuration in `devices/`
2. Add nixosConfiguration in `flake.nix`
3. Add public key to `yubikeys/` for secret management
4. Run `nix run .#agenix-rekey` to rekey secrets
