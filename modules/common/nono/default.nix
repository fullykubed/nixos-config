{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.versions = {
    nono = lib.mkOption {
      type = lib.types.str;
      description = "Version of nono CLI tool";
    };
    nonoSrcHash = lib.mkOption {
      type = lib.types.str;
      description = "Source hash for nono";
    };
    nonoCargoHash = lib.mkOption {
      type = lib.types.str;
      description = "Cargo hash for nono";
    };
  };

  config =
    let
      inherit (config) versions;

      nono = pkgs.rustPlatform.buildRustPackage {
        pname = "nono";
        version = versions.nono;

        src = pkgs.fetchFromGitHub {
          owner = "always-further";
          repo = "nono";
          rev = "v${versions.nono}";
          hash = versions.nonoSrcHash;
        };

        cargoHash = versions.nonoCargoHash;

        nativeBuildInputs = [ pkgs.pkg-config ];
        buildInputs = [ pkgs.dbus ];

        meta = with pkgs.lib; {
          description = "OS-enforced capability sandbox for AI agents";
          homepage = "https://nono.sh";
          license = licenses.asl20;
          mainProgram = "nono";
        };
      };
    in
    {
      environment.systemPackages = [ nono ];

      # Zsh completions (if nono supports `nono completions zsh`)
      home-manager.users.${config.username} = {
        programs.zsh.initContent = ''
          eval "$(nono completions zsh 2>/dev/null)"
        '';
      };
    };
}
