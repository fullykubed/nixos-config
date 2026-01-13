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

    # Bubblewrap wrapper utilities
    nix-bwrapper = {
      url = "github:Naxdy/nix-bwrapper";
      inputs.nixpkgs.follows = "nixpkgs";
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
      stylix,
      ...
    }:
    let
      # =========================================================================
      # Centralized Version Configuration
      # All package versions and hashes are defined here for easy reference
      # =========================================================================
      versions = {
        # workmux (modules/common/tmux)
        workmux = "0.1.89";
        workmuxRev = "456eae3fa8fdfde26af26d1c00e901f592fc977c";
        workmuxSrcHash = "sha256-MG2KTxQvOiRSusxfB1FbfPohAui05EOVPOFoezlU5mI=";
        workmuxCargoHash = "sha256-97q6gvHkq6cIx5VyXfytLVhtc1NsBtJd55FKjrRZTA8=";

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

        # ImageMagick override (overlay below)
        imagemagick = "7.1.2-3";
        imagemagickSrcHash = "sha256-L4apUdF1VJXSVqWAyjYFG/4qDJoJ0ObmSOpd90kqXsU=";
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

            # Global ImageMagick downgrade to fix gscan2pdf issues
            # See: https://github.com/NixOS/nixpkgs/issues/355168#issuecomment-3418603081
            (_: prev: {
              imagemagick = prev.imagemagick.overrideAttrs (_: {
                version = versions.imagemagick;
                src = prev.fetchFromGitHub {
                  owner = "ImageMagick";
                  repo = "ImageMagick";
                  tag = versions.imagemagick;
                  hash = versions.imagemagickSrcHash;
                };
              });
            })

            agenix-rekey.overlays.default
            nix-bwrapper.overlays.default
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
            (pkgs.writeShellScriptBin "un" (
              # Remove the shebang line since writeShellScriptBin adds its own
              builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] (
                builtins.readFile ./modules/common/scripts/scripts/un.sh
              )
            ))
          ]
          ++ self.checks.${system}.pre-commit-check.enabledPackages;

          inherit (self.checks.${system}.pre-commit-check) shellHook;
        };
      }
    );
}
