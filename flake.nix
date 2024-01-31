{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-23.11;
    nixpkgs-unstable.url = github:NixOS/nixpkgs/nixos-unstable;
    lanzaboote.url = "github:nix-community/lanzaboote";
    home-manager = {
      url = github:nix-community/home-manager/release-23.11;
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixpkgs-unstable, lanzaboote}:
  let
    system = "x86_64-linux";
    overlay-unstable = final: prev: {
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };
  in {
    nixosConfigurations.jack-desktop = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        # Overlays-module makes "pkgs.unstable" available in configuration.nix
        ({ config, pkgs, ... }: { nixpkgs.overlays = [ overlay-unstable ]; })

        # Used for setting up secureboot (not yet upstreamed into NixOS)
        lanzaboote.nixosModules.lanzaboote

        # NixOS Configuration
        ./configuration.nix

        # Home Manager Configuration
        home-manager.nixosModules.home-manager
        ({ config, pkgs, lib, ... }: {
          home-manager.users.jack = import ./home-manager/default.nix { inherit pkgs lib config; };
        })
      ];

    };
  };
}