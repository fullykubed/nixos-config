{
  inputs = {
    # Flake utilities
    flake-utils.url = "github:numtide/flake-utils";

    # Secrets management
    agenix.url = "https://flakehub.com/f/ryantm/agenix/0.15.0";
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey?ref=395cdb1631e9715e37d0e859a2b1da63f0ae333b";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate Nix to replace base nix
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3.8";

    # Nixpkg repositories (stable and unstable)
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2505";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    # Secure boot integrations
    lanzaboote = {
      url = "https://flakehub.com/f/nix-community/lanzaboote/0.4.2";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Home manager
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.2505";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # Bubblewrap wrapper utilities
    nix-bwrapper = {
      url = "github:Naxdy/nix-bwrapper";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      determinate,
      nixpkgs,
      home-manager,
      nixpkgs-unstable,
      lanzaboote,
      agenix,
      agenix-rekey,
      flake-utils,
      nix-bwrapper,
    }:
    let

      # Overlays module
      overlays =
        system:
        (
          { config, pkgs, ... }:
          {
            nixpkgs.overlays = [
              (final: prev: {
                # Makes "unstable" available in configuration.nix
                unstable = import nixpkgs-unstable {
                  inherit system;
                  config.allowUnfree = true;
                };
              })

              agenix-rekey.overlays.default
              nix-bwrapper.overlays.default
            ];
          }
        );

      mkNixosSystem =
        { system, device-module }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [

            # Load the Determinate module
            determinate.nixosModules.default

            # Load the overlays
            (overlays system)

            # Load the device-specific module
            device-module

            # Used for setting up secureboot (not yet upstreamed into NixOS)
            lanzaboote.nixosModules.lanzaboote

            # NixOS Configuration
            ./configuration.nix

            # Home Manager Configuration
            home-manager.nixosModules.home-manager
            (
              {
                config,
                pkgs,
                lib,
                ...
              }:
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;

                home-manager.users.${config.username} = import ./home-manager/default.nix {
                  inherit pkgs lib config;
                };
              }
            )

            # Secrets integrations
            agenix.nixosModules.default
            agenix-rekey.nixosModules.default

            # Options
            (
              { config, ... }:
              {
                username = "jack";
              }
            )
          ];
        };

    in
    {
      nixosConfigurations = {
        fullykubed-tower = mkNixosSystem {
          system = "x86_64-linux";
          device-module = ./devices/tower.nix;
        };
        fullykubed-mini-pc = mkNixosSystem {
          system = "x86_64-linux";
          device-module = ./devices/mini-pc.nix;
        };
      };

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = self.nixosConfigurations;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ agenix-rekey.overlays.default ];
        };
        nixfmt = pkgs.treefmt.withConfig {
          runtimeInputs = [ pkgs.nixfmt-rfc-style ];

          settings = {
            # Log level for files treefmt won't format
            on-unmatched = "info";

            # Configure nixfmt for .nix files
            formatter.nixfmt = {
              command = "nixfmt";
              includes = [ "*.nix" ];
            };
          };
        };
      in
      {
        formatter = nixfmt;
        devShell = pkgs.mkShell {
          packages = [
            nixfmt
            pkgs.agenix-rekey
            (pkgs.writeShellScriptBin "un" (
              # Remove the shebang line since writeShellScriptBin adds its own
              builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (
                builtins.readFile ./modules/common/scripts/scripts/un.sh
              )
            ))
          ];
        };
      }
    );
}
