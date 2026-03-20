{
  inputs = {
    # Flake utilities
    flake-utils.url = "github:numtide/flake-utils";

    # Secrets management
    agenix.url = "https://flakehub.com/f/ryantm/agenix/0.15.0";
    agenix-rekey = {
      url = "github:IanHollow/agenix-rekey?ref=fix-string-context-derivation-warning";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate Nix to replace base nix
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3.15";

    # Nixpkg repositories (stable and unstable)
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.2511";
    nixpkgs-unstable.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";

    # Secure boot integrations
    lanzaboote = {
      url = "https://flakehub.com/f/nix-community/lanzaboote/1.0.0";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home manager
    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0.2511";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    # System-wide theming
    stylix = {
      url = "github:nix-community/stylix/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Git hooks for pre-commit checks
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # S3-compatible binary cache
    niks3 = {
      url = "github:Mic92/niks3";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Bun to Nix converter for Bun projects
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pre-built nix-index database (replaces command-not-found)
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
      disko,
      agenix,
      agenix-rekey,
      flake-utils,
      stylix,
      niks3,
      bun2nix,
      nix-index-database,
      ...
    }:
    let
      versions = import ./lib/versions.nix;
      cacheModule = import ./modules/utility/cache-module.nix;
      casModule = import ./modules/utility/cas-module.nix;

      mkDiskImage = import ./images/mk-disk-image.nix { inherit nixpkgs determinate; };

      mkNixosSystem = import ./lib/mk-nixos-system.nix {
        inherit
          nixpkgs
          nixpkgs-unstable
          determinate
          lanzaboote
          disko
          stylix
          home-manager
          nix-index-database
          agenix
          agenix-rekey
          niks3
          bun2nix
          versions
          cacheModule
          casModule
          ;
      };

      machineConfigs =
        nixpkgs.lib.mapAttrs'
          (
            filename: _:
            let
              name = nixpkgs.lib.removeSuffix ".nix" filename;
            in
            nixpkgs.lib.nameValuePair "fullykubed-${name}" (mkNixosSystem {
              system = "x86_64-linux";
              machine-module = ./machines/${filename};
            })
          )
          (
            nixpkgs.lib.filterAttrs (n: t: t == "regular" && nixpkgs.lib.hasSuffix ".nix" n) (
              builtins.readDir ./machines
            )
          );

      mkInstaller =
        targetMachine:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self targetMachine; };
          modules = [ ./lib/installer ];
        };

    in
    {
      nixosConfigurations = machineConfigs;

      agenix-rekey = agenix-rekey.configure {
        userFlake = self;
        nixosConfigurations = machineConfigs;
      };

      packages.x86_64-linux =  {
        builder-image = import ./images/builder { inherit mkDiskImage niks3; };
        controller-image = import ./images/controller { inherit mkDiskImage niks3; };
      }
      // nixpkgs.lib.mapAttrs' (
        name: _:
        nixpkgs.lib.nameValuePair "installer-iso-${name}" (mkInstaller name).config.system.build.isoImage
      ) machineConfigs;

      # Per-host package sets for building/comparing individual derivations:
      #   nix build .#fullykubed-tower.stable.k9s --no-link
      #   nix eval .#fullykubed-mini-pc.unstable.k9s.version
      legacyPackages.x86_64-linux = builtins.mapAttrs (_: cfg: {
        stable = cfg.pkgs;
        unstable = cfg.config.nixpkgs-unstable.pkgs;
      }) self.nixosConfigurations;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      import ./lib/devshell {
        inherit
          nixpkgs
          self
          inputs
          agenix-rekey
          ;
      } system
    );
}
