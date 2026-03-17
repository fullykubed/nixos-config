# NixOS system builder
# Assembles a complete NixOS configuration from a device module and flake inputs
{
  nixpkgs,
  nixpkgs-unstable,
  determinate,
  lanzaboote,
  disko,
  stylix,
  home-manager,
  nix-index-database,
  agenix,
  agenix-rekey,
  niks3,
  bun2nix,
  versions,
  cacheModule,
}:
{ system, device-module }:
nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit system;
    nixpkgs-unstable-input = nixpkgs-unstable;
    stylix-home-module = stylix.homeModules.stylix;
    nix-index-database-home-module = nix-index-database.homeModules.nix-index;
  };
  modules = [

    # Provides nixpkgs-unstable module argument with nixpkgs-unstable.overlays option
    ../lib/nixpkgs-unstable.nix

    # Shared binary cache configuration
    cacheModule

    # Load the Determinate module
    determinate.nixosModules.default

    # Set version values (options are defined in their respective modules)
    { config.versions = versions; }

    # Overlays
    (_: {
      nixpkgs.overlays = [
        (_: _: { niks3-cli = niks3.packages.${system}.default; })
        (_: _: { bun2nix-cli = bun2nix.packages.${system}.default; })
        agenix-rekey.overlays.default
      ];
    })

    # Load the device-specific module
    device-module

    # Used for setting up secureboot (not yet upstreamed into NixOS)
    lanzaboote.nixosModules.lanzaboote

    # Declarative disk management
    disko.nixosModules.disko

    # System-wide theming
    stylix.nixosModules.stylix

    # NixOS Configuration
    ../modules

    # Home Manager
    home-manager.nixosModules.home-manager

    # Pre-built nix-index database (replaces command-not-found)
    nix-index-database.nixosModules.nix-index

    # Secrets integrations
    agenix.nixosModules.default
    agenix-rekey.nixosModules.default

    # Options
    {
      username = "jack";
    }
  ];
}
