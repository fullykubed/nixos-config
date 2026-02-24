{
  inputs = {
    # Flake utilities
    flake-utils.url = "github:numtide/flake-utils";

    # Secrets management
    agenix.url = "https://flakehub.com/f/ryantm/agenix/0.15.0";
    agenix-rekey = {
      url = "github:oddlama/agenix-rekey?ref=42362b12f59978aabf3ec3334834ce2f3662013d";
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
      stylix,
      niks3,
      ...
    }:
    let
      # =========================================================================
      # Centralized Version Configuration
      # All package versions and hashes are defined here for easy reference
      # =========================================================================
      versions = {
        # workmux (modules/common/tmux)
        workmux = "0.1.100";
        workmuxRev = "d428a715a9cc2d8f487e4ba5e6d273c7240a2b3a";
        workmuxSrcHash = "sha256-9i+pdX6dS8KSk7QrMAIlpCqqBH+YgA8CTizVQ5xpv+A=";
        workmuxCargoHash = "sha256-KnDMLpq7MOPcTAM+Nb0HrGd7oPpHhbrFEXwCg7bmGDQ=";

        # tmux-autoreload plugin (modules/common/tmux)
        tmuxAutoreload = "unstable-2024-01-01";
        tmuxAutoreloadRev = "e98aa3b74cfd5f2df2be2b5d4aa4ddcc843b2eba";
        tmuxAutoreloadHash = "sha256-9Rk+VJuDqgsjc+gwlhvX6uxUqpxVD1XJdQcsc5s4pU4=";

        # tmux-notify plugin (modules/common/tmux)
        tmuxNotify = "unstable-2024-11-18";
        tmuxNotifyRev = "b713320af05837c3b44e4d51167ff3062dbeae4b";
        tmuxNotifyHash = "sha256-wOmq2stWXAFmYrRuIqf9IPATYXJ+OFoYXnJdHUnJQxY=";

        # lazyworktree (modules/common/git/lazyworktree)
        lazyworktree = "1.21.1";
        lazyworktreeSrcHash = "sha256-5ercx4htJ1GS7nGwK/BeIGrt4ZQLql4Z4pDTVTWZH8o=";
        lazyworktreeVendorHash = "sha256-0O8i84mzAYq/VUWn0vbHf218hwXRMAvlfKnBUYXo8Ck=";

        # voxtype (modules/common/transcription)
        voxtype = "0.4.12";
        voxtypeSrcHash = "sha256-rMTfLvllr2zn+799+YTgE53Ve0khdE9FPaLtxF2pk58=";
        voxtypeCargoHash = "sha256-VbqHyOA0BA8PpFrOvdaHi3Bv3IuTXhnlsOfrmNH6FHU=";

        # ccusage (modules/common/claude)
        ccusage = "16.2.5";
        ccusageSrcHash = "sha256-GXleBpZ3XF4DWrXG31Kh15SoOLRm6kXuuvIEEEmQ8eA=";

        # brscan5 Brother scanner driver (modules/utility/brother-scanner)
        brscan5 = "1.3.1-0";
        brscan5Hash = "sha256-0UMbXMBlyiZI90WG5FWEP2mIZEBsxXd11dtgtyuSDnY=";
      };

      # =========================================================================
      # Shared Binary Cache Configuration
      # =========================================================================
      cacheModule = {
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
      };

      # =========================================================================
      # Custom Packages Overlay
      # =========================================================================
      customPackagesOverlay = final: _prev: {
        hcloud-upload-image = final.buildGoModule rec {
          pname = "hcloud-upload-image";
          version = "1.3.0";
          src = final.fetchFromGitHub {
            owner = "apricote";
            repo = "hcloud-upload-image";
            rev = "v${version}";
            hash = "sha256-1u9tpzciYjB/EgBI81pg9w0kez7hHZON7+AHvfKW7k0=";
          };
          vendorHash = "sha256-IdOAUBPg0CEuHd2rdc7jOlw0XtnAhr3PVPJbnFs2+x4=";
          env.GOWORK = "off";
          subPackages = [ "." ];
          ldflags = [
            "-s"
            "-w"
            "-X main.version=${version}"
          ];
        };
      };

      # =========================================================================
      # Overlays
      # =========================================================================
      overlays =
        system:
        (_: {
          nixpkgs.overlays = [
            (_: _: {
              # Makes "unstable" available in configuration.nix
              unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
            })

            # niks3 binary cache CLI
            (_: _: {
              niks3-cli = niks3.packages.${system}.default;
            })

            # Custom packages
            customPackagesOverlay

            # Security patches for CVEs not yet in nixpkgs
            (import ./patches)

            agenix-rekey.overlays.default
          ];
        });

      # =========================================================================
      # NixOS System Builder
      # =========================================================================
      mkNixosSystem =
        { system, device-module }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [

            # Shared binary cache configuration
            cacheModule

            # Load the Determinate module
            determinate.nixosModules.default

            # Set version values (options are defined in their respective modules)
            { config.versions = versions; }

            # Load the overlays
            (overlays system)

            # Load the device-specific module
            device-module

            # Used for setting up secureboot (not yet upstreamed into NixOS)
            lanzaboote.nixosModules.lanzaboote

            # System-wide theming
            stylix.nixosModules.stylix

            # NixOS Configuration
            ./configuration.nix

            # Home Manager Configuration
            home-manager.nixosModules.home-manager
            (
              {
                config,
                ...
              }:
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  sharedModules = [ stylix.homeModules.stylix ];
                  users.${config.username} = {
                    home.stateVersion = "22.11";

                    # Disable manual generation to avoid builtins.toFile warning
                    # See: https://github.com/nix-community/home-manager/issues/7935
                    manual.manpages.enable = false;
                  };
                  users.root = {
                    home.stateVersion = "22.11";
                    manual.manpages.enable = false;
                  };
                };
              }
            )

            # Secrets integrations
            agenix.nixosModules.default
            agenix-rekey.nixosModules.default

            # Options
            {
              username = "jack";
            }
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
        inherit (self) nixosConfigurations;
      };

      # Builder image using native nixpkgs make-disk-image
      packages.x86_64-linux.builder-image =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          builderSystem = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              cacheModule
              determinate.nixosModules.default
              ./builders/image.nix
              # Make niks3 CLI available
              {
                nixpkgs.overlays = [
                  (_: _: {
                    niks3-cli = niks3.packages.x86_64-linux.default;
                  })
                ];
              }
              # Root filesystem for disk image
              {
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                  autoResize = true;
                };
              }
            ];
          };
        in
        pkgs.callPackage "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit pkgs;
          inherit (pkgs) lib;
          inherit (builderSystem) config;
          format = "raw";
          diskSize = "auto";
          additionalSpace = "2G";
          partitionTableType = "efi";
          copyChannel = false;
          label = "nixos";
          postVM = ''
            ${pkgs.zstd}/bin/zstd -6 --rm -f $diskImage -o $out/nixos.img.zst
          '';
        };

      # Cache server image using native nixpkgs make-disk-image
      packages.x86_64-linux.cache-image =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
          cacheSystem = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              cacheModule
              niks3.nixosModules.default
              ./cache/image.nix
              # Root filesystem for disk image
              {
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                  autoResize = true;
                };
              }
            ];
          };
        in
        pkgs.callPackage "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit pkgs;
          inherit (pkgs) lib;
          inherit (cacheSystem) config;
          format = "raw";
          diskSize = "auto";
          additionalSpace = "4G";
          partitionTableType = "efi";
          copyChannel = false;
          label = "nixos";
          postVM = ''
            ${pkgs.zstd}/bin/zstd -6 --rm -f $diskImage -o $out/nixos.img.zst
          '';
        };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            customPackagesOverlay
            agenix-rekey.overlays.default
          ];
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
        checks = {
          pre-commit-check = inputs.git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixfmt-rfc-style.enable = true;
              statix.enable = true;
              deadnix.enable = true;
              gitleaks = {
                enable = true;
                name = "gitleaks";
                # Use protect mode to only scan staged changes, not full history
                entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged -v --config ${./gitleaks.toml}";
              };
            };
          };
        };

        formatter = nixfmt;
        devShell = pkgs.mkShell {
          packages = [
            nixfmt
            pkgs.agenix-rekey
            pkgs.gitleaks
            pkgs.hcloud
            pkgs.hcloud-upload-image
          ]
          ++ self.checks.${system}.pre-commit-check.enabledPackages;

          inherit (self.checks.${system}.pre-commit-check) shellHook;
        };
      }
    );
}
